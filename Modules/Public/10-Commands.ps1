function Invoke-AzureLocalRanger {
    <#
    .SYNOPSIS
        Runs the AzureLocalRanger discovery and reporting pipeline against an Azure Local cluster.

    .DESCRIPTION
        Invoke-AzureLocalRanger is the primary entry point for the AzureLocalRanger module.
        It loads configuration, resolves credentials, executes all enabled collectors against
        the target cluster and its nodes, then renders the requested output report formats
        (HTML, Markdown, DOCX, XLSX, PDF, and SVG diagrams).

        Structural override parameters (ClusterFqdn, ClusterNodes, etc.) take precedence over
        values in the configuration file, making it convenient to run one-off assessments without
        modifying config files.

    .PARAMETER ConfigPath
        Path to a Ranger YAML or JSON configuration file. Use New-AzureLocalRangerConfig to
        generate a starter file. When omitted, Ranger applies built-in defaults only.

    .PARAMETER ConfigObject
        An in-memory hashtable or PSCustomObject representing configuration. Merged over defaults.
        Useful for pipeline scenarios where config is constructed programmatically.

    .PARAMETER OutputPath
        Directory to write the report package. Defaults to config output.rootPath
        (C:\AzureLocalRanger) with a dated sub-folder per run.

    .PARAMETER IncludeDomain
        Limit collection to the specified domain FQDNs. Overrides config domains.include.

    .PARAMETER ExcludeDomain
        Skip the specified domain FQDNs during collection. Overrides config domains.exclude.

    .PARAMETER ClusterCredential
        PSCredential used to connect to cluster nodes via WinRM. Overrides config
        credentials.cluster.

    .PARAMETER DomainCredential
        PSCredential used for Active Directory / domain queries. Overrides config
        credentials.domain.

    .PARAMETER BmcCredential
        PSCredential used for BMC (iDRAC / iLO) access. Overrides config credentials.bmc.

    .PARAMETER NoRender
        Collect data but skip report rendering. The raw manifest JSON is still written.

    .PARAMETER Unattended
        Suppress interactive prompts and fail the PowerShell process when a collector ends in
        the failed state. Intended for Task Scheduler, CI, and other scheduled runs.

    .PARAMETER BaselineManifestPath
        Path to a previous audit-manifest.json file. When provided, Ranger compares the new
        manifest against the baseline and writes drift-report.json into the package.

    .PARAMETER ClusterFqdn
        FQDN or NetBIOS name of the cluster name object (CNO). Overrides
        config targets.cluster.fqdn.

    .PARAMETER ClusterNodes
        List of node FQDNs or NetBIOS names to target. Overrides config
        targets.cluster.nodes.

    .PARAMETER EnvironmentName
        Short identifier for the environment (used in report filenames). Overrides
        config environment.name.

    .PARAMETER SubscriptionId
        Azure subscription ID containing the Arc-enabled HCI resource. Overrides
        config targets.azure.subscriptionId.

    .PARAMETER TenantId
        Azure Entra tenant ID. Overrides config targets.azure.tenantId.

    .PARAMETER ResourceGroup
        Azure resource group name that contains the Arc-enabled HCI cluster resource.
        Overrides config targets.azure.resourceGroup.

    .PARAMETER ShowProgress
        Display a live Spectre.Console progress bar during collector execution.
        Requires the PwshSpectreConsole module. Automatically suppressed in CI and
        Unattended mode. Overrides config output.showProgress.

    .PARAMETER OutputMode
        Report mode: current-state or as-built. Overrides config output.mode.

    .PARAMETER OutputFormats
        Comma-separated or array of formats to render: html, markdown, docx, xlsx, pdf, svg, drawio.
        Overrides config output.formats.

    .PARAMETER Transport
        WinRM transport mode: auto, winrm, or arc. Overrides config behavior.transport.
        auto tries WinRM first and falls back to Arc Run Command when nodes are unreachable.

    .PARAMETER DegradationMode
        How to handle collectors whose transport is unavailable: graceful or strict.
        graceful skips with status skipped; strict fails the run. Overrides config behavior.degradationMode.

    .PARAMETER RetryCount
        Number of WinRM retry attempts per operation. Overrides config behavior.retryCount.

    .PARAMETER TimeoutSeconds
        WinRM operation timeout in seconds. Overrides config behavior.timeoutSeconds.

    .PARAMETER AzureMethod
        Azure authentication method: existing-context, managed-identity, device-code, service-principal,
        or azure-cli. Overrides config credentials.azure.method.

    .PARAMETER ClusterName
        Display name for the cluster used in reports. Overrides config environment.clusterName.

    .PARAMETER ResourceGroupLocation
        Azure region for the resource group. Overrides config targets.azure.location when needed.

    .OUTPUTS
        System.Collections.Hashtable — the completed run manifest. Also writes report files
        to the output directory.

    .EXAMPLE
        # Run using a config file
        Invoke-AzureLocalRanger -ConfigPath .\ranger.yml

    .EXAMPLE
        # Quick one-off run with inline overrides — no config file needed
        Invoke-AzureLocalRanger `
            -ClusterFqdn azlocal-prod.contoso.com `
            -ClusterNodes azl-n01.contoso.com,azl-n02.contoso.com `
            -ClusterCredential (Get-Credential) `
            -SubscriptionId '<guid>' `
            -ResourceGroup rg-azlocal-prod

    .EXAMPLE
        # Collect only; skip report rendering
        Invoke-AzureLocalRanger -ConfigPath .\ranger.yml -NoRender

    .EXAMPLE
        # Run non-interactively on a schedule and compare with a prior manifest
        Invoke-AzureLocalRanger -ConfigPath .\ranger.yml -Unattended -BaselineManifestPath .\baseline\audit-manifest.json

    .LINK
        https://azurelocal.github.io/azurelocal-ranger/prerequisites/

    .LINK
        https://azurelocal.github.io/azurelocal-ranger/operator/command-reference/
    #>
    [CmdletBinding()]
    param(
        [string]$ConfigPath,
        $ConfigObject,
        [string]$OutputPath,
        [string[]]$IncludeDomain,
        [string[]]$ExcludeDomain,
        [PSCredential]$ClusterCredential,
        [PSCredential]$DomainCredential,
        [PSCredential]$BmcCredential,
        [switch]$NoRender,
        [switch]$Unattended,
        [string]$BaselineManifestPath,

        # Issue #115: structural overrides — any of these win over the config file value
        [string]$ClusterFqdn,
        [string[]]$ClusterNodes,
        [string]$EnvironmentName,
        [string]$SubscriptionId,
        [string]$TenantId,
        [string]$ResourceGroup,

        # Issue #76: show live progress bars during collector execution
        [switch]$ShowProgress,

        # Issue #171: full config key coverage as runtime parameters
        [ValidateSet('current-state', 'as-built')]
        [string]$OutputMode,

        [string[]]$OutputFormats,

        [ValidateSet('auto', 'winrm', 'arc')]
        [string]$Transport,

        [ValidateSet('graceful', 'strict')]
        [string]$DegradationMode,

        [int]$RetryCount,

        [int]$TimeoutSeconds,

        [ValidateSet('existing-context', 'managed-identity', 'device-code', 'service-principal', 'azure-cli')]
        [string]$AzureMethod,

        [string]$ClusterName
    )

    $credentialOverrides = @{
        cluster = $ClusterCredential
        domain  = $DomainCredential
        bmc     = $BmcCredential
    }

    $structuralOverrides = @{}
    if ($PSBoundParameters.ContainsKey('ClusterFqdn'))       { $structuralOverrides['ClusterFqdn']       = $ClusterFqdn }
    if ($PSBoundParameters.ContainsKey('ClusterNodes'))      { $structuralOverrides['ClusterNodes']      = $ClusterNodes }
    if ($PSBoundParameters.ContainsKey('EnvironmentName'))   { $structuralOverrides['EnvironmentName']   = $EnvironmentName }
    if ($PSBoundParameters.ContainsKey('ClusterName'))       { $structuralOverrides['ClusterName']       = $ClusterName }
    if ($PSBoundParameters.ContainsKey('SubscriptionId'))    { $structuralOverrides['SubscriptionId']    = $SubscriptionId }
    if ($PSBoundParameters.ContainsKey('TenantId'))          { $structuralOverrides['TenantId']          = $TenantId }
    if ($PSBoundParameters.ContainsKey('ResourceGroup'))     { $structuralOverrides['ResourceGroup']     = $ResourceGroup }
    if ($PSBoundParameters.ContainsKey('ShowProgress'))      { $structuralOverrides['ShowProgress']      = [bool]$ShowProgress }
    if ($PSBoundParameters.ContainsKey('OutputMode'))        { $structuralOverrides['OutputMode']        = $OutputMode }
    if ($PSBoundParameters.ContainsKey('OutputFormats'))     { $structuralOverrides['OutputFormats']     = $OutputFormats }
    if ($PSBoundParameters.ContainsKey('Transport'))         { $structuralOverrides['Transport']         = $Transport }
    if ($PSBoundParameters.ContainsKey('DegradationMode'))   { $structuralOverrides['DegradationMode']   = $DegradationMode }
    if ($PSBoundParameters.ContainsKey('RetryCount'))        { $structuralOverrides['RetryCount']        = $RetryCount }
    if ($PSBoundParameters.ContainsKey('TimeoutSeconds'))    { $structuralOverrides['TimeoutSeconds']    = $TimeoutSeconds }
    if ($PSBoundParameters.ContainsKey('AzureMethod'))       { $structuralOverrides['AzureMethod']       = $AzureMethod }

    Invoke-RangerDiscoveryRuntime -ConfigPath $ConfigPath -ConfigObject $ConfigObject -OutputPath $OutputPath -CredentialOverrides $credentialOverrides -IncludeDomains $IncludeDomain -ExcludeDomains $ExcludeDomain -NoRender:$NoRender -StructuralOverrides $structuralOverrides -AllowInteractiveInput:(-not $Unattended) -Unattended:$Unattended -BaselineManifestPath $BaselineManifestPath
}

function New-AzureLocalRangerConfig {
    <#
    .SYNOPSIS
        Generates a new, self-documenting AzureLocalRanger configuration file.

    .DESCRIPTION
        New-AzureLocalRangerConfig writes a starter configuration to disk in YAML (default)
        or JSON format. The YAML output includes inline comments that describe every key and
        mark fields that must be filled in before running Invoke-AzureLocalRanger.

    .PARAMETER Path
        Destination path for the configuration file, e.g. C:\ranger\ranger.yml.
        The parent directory is created if it does not already exist.

    .PARAMETER Format
        Output format. Accepted values: yaml (default), json.

    .PARAMETER Force
        Overwrite an existing file at Path. Without this switch the command will throw
        if the file already exists.

    .OUTPUTS
        System.IO.FileInfo — the newly created configuration file.

    .EXAMPLE
        New-AzureLocalRangerConfig -Path C:\ranger\ranger.yml

    .EXAMPLE
        New-AzureLocalRangerConfig -Path C:\ranger\ranger.json -Format json -Force
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [ValidateSet('yaml', 'json')]
        [string]$Format = 'yaml',

        [switch]$Force
    )

    $resolvedPath = Resolve-RangerPath -Path $Path
    if ((Test-Path -Path $resolvedPath) -and -not $Force) {
        throw "The configuration file already exists: $resolvedPath"
    }

    New-Item -ItemType Directory -Path (Split-Path -Parent $resolvedPath) -Force | Out-Null
    if ($Format -eq 'json') {
        Get-RangerDefaultConfig | ConvertTo-Json -Depth 50 | Set-Content -Path $resolvedPath -Encoding UTF8
    }
    else {
        Get-RangerAnnotatedConfigYaml | Set-Content -Path $resolvedPath -Encoding UTF8
    }

    Get-Item -Path $resolvedPath
}

function Export-AzureLocalRangerReport {
    <#
    .SYNOPSIS
        Re-renders report files from an existing Ranger run manifest.

    .DESCRIPTION
        Export-AzureLocalRangerReport reads a previously written ranger-manifest.json file
        and regenerates the requested output formats without re-running any collectors.
        Useful for producing additional formats or updating report templates after a run.

    .PARAMETER ManifestPath
        Path to the ranger-manifest.json file from a prior Invoke-AzureLocalRanger run.

    .PARAMETER OutputPath
        Directory to write the re-rendered reports. Defaults to the same directory as
        ManifestPath.

    .PARAMETER Formats
        Report formats to generate. Accepted values include html, markdown, docx,
        xlsx, pdf, svg, and drawio. Defaults to html, markdown, svg.

    .OUTPUTS
        None. Reports are written to the output directory.

    .EXAMPLE
        Export-AzureLocalRangerReport -ManifestPath 'C:\AzureLocalRanger\2025-01-15\ranger-manifest.json'

    .EXAMPLE
        Export-AzureLocalRangerReport `
            -ManifestPath .\ranger-manifest.json `
            -Formats html,markdown `
            -OutputPath C:\Reports
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ManifestPath,

        [string]$OutputPath,
        [string[]]$Formats = @('html', 'markdown', 'svg')
    )

    $resolvedManifestPath = Resolve-RangerPath -Path $ManifestPath
    if (-not (Test-Path -Path $resolvedManifestPath)) {
        throw "Manifest file not found: $resolvedManifestPath"
    }

    $manifest = Get-Content -Path $resolvedManifestPath -Raw | ConvertFrom-Json -AsHashtable -Depth 100
    $packageRoot = if ($OutputPath) { Resolve-RangerPath -Path $OutputPath } else { Split-Path -Parent $resolvedManifestPath }
    Invoke-RangerOutputGeneration -Manifest (ConvertTo-RangerHashtable -InputObject $manifest) -PackageRoot $packageRoot -Formats $Formats -Mode $manifest['run']['mode']
}

function Test-AzureLocalRangerPrerequisites {
    <#
    .SYNOPSIS
        Validates that all prerequisites for running AzureLocalRanger are satisfied.

    .DESCRIPTION
        Test-AzureLocalRangerPrerequisites checks for the required PowerShell version,
        WinRM cmdlets, RSAT Active Directory module, clustering cmdlets, Hyper-V cmdlets,
        the Az PowerShell modules, and Azure CLI. It also validates the provided
        configuration file.

        When -InstallPrerequisites is specified, the command automatically installs any
        missing components. RSAT-AD-PowerShell is installed via Install-WindowsFeature on
        Windows Server or Add-WindowsCapability on Windows Client / AVD multi-session.
        Az modules are installed from PSGallery with -Scope CurrentUser. An elevated
        (Administrator) session is required when -InstallPrerequisites is used.

    .PARAMETER ConfigPath
        Optional path to a Ranger configuration file to include in the validation pass.

    .PARAMETER ConfigObject
        Optional in-memory configuration hashtable to include in the validation pass.

    .PARAMETER InstallPrerequisites
        Automatically install missing RSAT AD and Az PowerShell modules. Requires
        an elevated (Administrator) session.

    .OUTPUTS
        System.Collections.Hashtable — contains Validation, SelectedCollectors, and Checks keys.

    .EXAMPLE
        # Check prerequisites without a config
        Test-AzureLocalRangerPrerequisites

    .EXAMPLE
        # Validate against a config file
        Test-AzureLocalRangerPrerequisites -ConfigPath .\ranger.yml

    .EXAMPLE
        # Auto-install missing components (requires elevated session)
        Test-AzureLocalRangerPrerequisites -ConfigPath .\ranger.yml -InstallPrerequisites
    #>
    # Issue #78: -InstallPrerequisites auto-installs RSAT AD and Az modules when missing.
    # Requires an elevated (Administrator) session.  Detects Server vs Client OS and uses
    # Install-WindowsFeature (Server) or Add-WindowsCapability (Client) for RSAT AD.
    [CmdletBinding()]
    param(
        [string]$ConfigPath,
        $ConfigObject,
        [switch]$InstallPrerequisites
        ,
        [string]$ClusterFqdn,
        [string[]]$ClusterNodes,
        [string]$EnvironmentName,
        [string]$SubscriptionId,
        [string]$TenantId,
        [string]$ResourceGroup
    )

    $structuralOverrides = @{}
    if ($PSBoundParameters.ContainsKey('ClusterFqdn'))     { $structuralOverrides['ClusterFqdn']     = $ClusterFqdn }
    if ($PSBoundParameters.ContainsKey('ClusterNodes'))    { $structuralOverrides['ClusterNodes']    = $ClusterNodes }
    if ($PSBoundParameters.ContainsKey('EnvironmentName')) { $structuralOverrides['EnvironmentName'] = $EnvironmentName }
    if ($PSBoundParameters.ContainsKey('SubscriptionId'))  { $structuralOverrides['SubscriptionId']  = $SubscriptionId }
    if ($PSBoundParameters.ContainsKey('TenantId'))        { $structuralOverrides['TenantId']        = $TenantId }
    if ($PSBoundParameters.ContainsKey('ResourceGroup'))   { $structuralOverrides['ResourceGroup']   = $ResourceGroup }

    if ($InstallPrerequisites) {
        $isElevated = ([Security.Principal.WindowsPrincipal]::new(
            [Security.Principal.WindowsIdentity]::GetCurrent()
        )).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

        if (-not $isElevated) {
            throw '-InstallPrerequisites requires an elevated (Administrator) PowerShell session.'
        }

        # RSAT AD (ActiveDirectory PS module)
        if (-not (Test-RangerCommandAvailable -Name 'Get-ADUser')) {
            if (Get-Command Install-WindowsFeature -ErrorAction SilentlyContinue) {
                # Windows Server — ServerManager cmdlet available
                Write-Verbose 'Installing RSAT-AD-PowerShell via Install-WindowsFeature (Server OS)...'
                Install-WindowsFeature -Name RSAT-AD-PowerShell -ErrorAction Stop | Out-Null
            } else {
                # Windows client or multi-session (Win10/11/AVD) — use DISM capability
                Write-Verbose 'Installing RSAT ActiveDirectory via Add-WindowsCapability (Client/multi-session OS)...'
                Add-WindowsCapability -Online -Name 'Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0' -ErrorAction Stop | Out-Null
            }
        }

        # Az modules required by Ranger collectors
        $azModulesNeeded = @('Az.Accounts', 'Az.Resources', 'Az.DesktopVirtualization', 'Az.Aks', 'Az.KeyVault')
        foreach ($mod in $azModulesNeeded) {
            if (-not (Get-Module -ListAvailable -Name $mod)) {
                Write-Verbose "Installing $mod from PSGallery..."
                Install-Module -Name $mod -Repository PSGallery -Force -AllowClobber -Scope CurrentUser -ErrorAction Stop
            }
        }
    }

    $clusterConnectivityPassed = $false
    $clusterConnectivityDetail = 'Cluster WinRM connectivity not tested.'
    $validation = [ordered]@{
        IsValid  = $true
        Errors   = @()
        Warnings = @()
    }
    $selectedCollectors = @()

    $hasConfigInput = $PSBoundParameters.ContainsKey('ConfigPath') -or $PSBoundParameters.ContainsKey('ConfigObject')
    $shouldBuildConfig = $hasConfigInput -or $structuralOverrides.Count -gt 0

    if ($shouldBuildConfig) {
        if ($hasConfigInput) {
            $config = Import-RangerConfiguration -ConfigPath $ConfigPath -ConfigObject $ConfigObject
        }
        else {
            $config = Get-RangerDefaultConfig
        }

        $config = Set-RangerStructuralOverrides -Config $config -StructuralOverrides $structuralOverrides
        $validation = Test-RangerConfiguration -Config $config -PassThru
        $selectedCollectors = Resolve-RangerSelectedCollectors -Config $config
        $probeConfig = ConvertTo-RangerHashtable -InputObject $config
        $probeConfig.behavior.promptForMissingCredentials = $false

        try {
            $probeCredentialMap = Resolve-RangerCredentialMap -Config $probeConfig -Overrides @{}
            $probeTargets = [System.Collections.Generic.List[string]]::new()
            if (-not [string]::IsNullOrWhiteSpace($probeConfig.targets.cluster.fqdn) -and -not (Test-RangerPlaceholderValue -Value $probeConfig.targets.cluster.fqdn -FieldName 'targets.cluster.fqdn')) {
                $probeTargets.Add([string]$probeConfig.targets.cluster.fqdn)
            }
            foreach ($node in @($probeConfig.targets.cluster.nodes)) {
                if (-not [string]::IsNullOrWhiteSpace([string]$node) -and -not (Test-RangerPlaceholderValue -Value $node -FieldName 'targets.cluster.node') -and $node -notin $probeTargets) {
                    $probeTargets.Add([string]$node)
                }
            }

            if ($probeTargets.Count -eq 0) {
                $clusterConnectivityDetail = 'No cluster WinRM targets are configured.'
            }
            else {
                $retryCount = if ($probeConfig.behavior -and $probeConfig.behavior.retryCount -gt 0) { [int]$probeConfig.behavior.retryCount } else { 1 }
                $timeoutSec = if ($probeConfig.behavior -and $probeConfig.behavior.timeoutSeconds -gt 0) { [int]$probeConfig.behavior.timeoutSeconds } else { 0 }
                $remoteExecution = Resolve-RangerRemoteExecutionCredential -Targets $probeTargets -ClusterCredential $probeCredentialMap.cluster -DomainCredential $probeCredentialMap.domain -RetryCount $retryCount -TimeoutSeconds $timeoutSec
                $clusterConnectivityPassed = $true
                $clusterConnectivityDetail = "$($remoteExecution.Detail) " + (@($remoteExecution.Results | ForEach-Object {
                    "$($_.Target): $($_.RemoteIdentity)"
                }) -join '; ')
            }
        }
        catch {
            $clusterConnectivityDetail = "Cluster WinRM connectivity probe failed: $($_.Exception.Message)"
        }
    }
    else {
        $clusterConnectivityPassed = $true
        $clusterConnectivityDetail = 'Skipped: no configuration or cluster overrides were supplied.'
        $validation.Warnings = @('No configuration was supplied. Config-specific validation and cluster connectivity checks were skipped.')
    }

    $checks = @(
        [ordered]@{ Name = 'PowerShell 7+';            Passed = $PSVersionTable.PSVersion.Major -ge 7;               Optional = $false; Detail = $PSVersionTable.PSVersion.ToString() },
        [ordered]@{ Name = 'WinRM cmdlets';            Passed = (Test-RangerCommandAvailable -Name 'Invoke-Command'); Optional = $false; Detail = 'Invoke-Command' },
        [ordered]@{ Name = 'Cluster WinRM connectivity'; Passed = $clusterConnectivityPassed;                        Optional = $false; Detail = $clusterConnectivityDetail },
        [ordered]@{ Name = 'RSAT AD';                  Passed = (Test-RangerCommandAvailable -Name 'Get-ADUser');    Optional = $false; Detail = 'Get-ADUser (required for identity domain collection)' },
        [ordered]@{ Name = 'Cluster cmdlets';          Passed = (Test-RangerCommandAvailable -Name 'Get-Cluster');   Optional = $true;  Detail = 'Get-Cluster (optional on runner, required on cluster nodes)' },
        [ordered]@{ Name = 'Hyper-V cmdlets';          Passed = (Test-RangerCommandAvailable -Name 'Get-VM');        Optional = $true;  Detail = 'Get-VM (optional on runner, required on cluster nodes)' },
        [ordered]@{ Name = 'Az modules';               Passed = (Test-RangerCommandAvailable -Name 'Get-AzContext'); Optional = $false; Detail = 'Get-AzContext' },
        [ordered]@{ Name = 'Azure CLI';                Passed = (Test-RangerCommandAvailable -Name 'az');            Optional = $true;  Detail = 'az (optional fallback for Azure auth)' },
        [ordered]@{ Name = 'Az.ConnectedMachine';      Passed = [bool](Get-Module -ListAvailable -Name 'Az.ConnectedMachine' -ErrorAction SilentlyContinue); Optional = $true; Detail = 'Optional — required for Arc Run Command transport (behavior.transport: arc/auto)' },
        [ordered]@{ Name = 'PwshSpectreConsole';       Passed = [bool](Get-Module -ListAvailable -Name 'PwshSpectreConsole' -ErrorAction SilentlyContinue);  Optional = $true; Detail = 'Optional — required for Spectre TUI progress display; falls back to Write-Progress when absent' },
        [ordered]@{ Name = 'Pester';                   Passed = (Test-RangerCommandAvailable -Name 'Invoke-Pester'); Optional = $true;  Detail = 'Invoke-Pester (required for contributor testing only)' }
    )

    # Issue #169: write a human-readable summary to the host before returning the
    # structured result. Programmatic callers can still capture the return value.
    $passCount    = @($checks | Where-Object { $_.Passed }).Count
    $failRequired = @($checks | Where-Object { -not $_.Passed -and -not $_.Optional })
    $warnOptional = @($checks | Where-Object { -not $_.Passed -and $_.Optional })

    Write-Host ''
    Write-Host 'AzureLocalRanger — Prerequisite Check' -ForegroundColor Cyan
    Write-Host ('─' * 60) -ForegroundColor DarkGray
    foreach ($check in $checks) {
        $label  = $check.Name.PadRight(28)
        $detail = $check.Detail
        if ($check.Passed) {
            Write-Host "  $label " -NoNewline
            Write-Host 'Pass' -ForegroundColor Green -NoNewline
            Write-Host "  $detail" -ForegroundColor DarkGray
        } elseif ($check.Optional) {
            Write-Host "  $label " -NoNewline
            Write-Host 'Warn' -ForegroundColor Yellow -NoNewline
            Write-Host "  $detail" -ForegroundColor DarkGray
        } else {
            Write-Host "  $label " -NoNewline
            Write-Host 'FAIL' -ForegroundColor Red -NoNewline
            Write-Host "  $detail"
        }
    }
    Write-Host ('─' * 60) -ForegroundColor DarkGray

    if ($failRequired.Count -eq 0) {
        Write-Host "  Overall  " -NoNewline
        Write-Host 'PASS' -ForegroundColor Green -NoNewline
        Write-Host "  ($passCount/$($checks.Count) checks passed, $($warnOptional.Count) optional warning(s))"
    } else {
        Write-Host "  Overall  " -NoNewline
        Write-Host 'FAIL' -ForegroundColor Red -NoNewline
        Write-Host "  ($($failRequired.Count) required check(s) failed)"
    }

    if ($selectedCollectors.Count -gt 0) {
        Write-Host ''
        Write-Host "  Selected collectors: $(($selectedCollectors | ForEach-Object { $_.Id }) -join ', ')" -ForegroundColor DarkGray
    }
    Write-Host ''

    [ordered]@{
        Validation         = $validation
        SelectedCollectors = @($selectedCollectors | ForEach-Object { $_.Id })
        Checks             = $checks
    }
}

function Invoke-RangerWizard {
    <#
    .SYNOPSIS
        Interactively guides you through building a Ranger configuration and optionally launches a run.

    .DESCRIPTION
        Invoke-RangerWizard walks through a prompted question sequence to collect:
          • Cluster FQDN and node list
          • Azure subscription ID, tenant ID, and resource group
          • Credential strategy (current context, prompt, or path to a saved credential)
          • Output path and report formats
          • Scope selection (domains to include / exclude)

        At the end of the sequence you can either:
          (S) Save the configuration to a YAML file, or
          (R) Run immediately using the collected configuration, or
          (B) Both — save and run.

        The wizard requires an interactive host. In non-interactive sessions it throws an
        InvalidOperationException rather than attempting to run.

    .PARAMETER OutputConfigPath
        Pre-fill the save path for the generated config file. If not supplied the wizard prompts.

    .PARAMETER SkipRun
        Complete the wizard and save the config file, but do not launch a run regardless of
        the user's choice at the end of the session.

    .EXAMPLE
        Invoke-RangerWizard

    .EXAMPLE
        Invoke-RangerWizard -OutputConfigPath C:\ranger\new-env.yml

    .LINK
        https://azurelocal.github.io/azurelocal-ranger/operator/wizard/
    #>
    [CmdletBinding()]
    param(
        [string]$OutputConfigPath,
        [switch]$SkipRun
    )

    if (-not (Test-RangerInteractivePromptAvailable)) {
        throw [System.InvalidOperationException]::new(
            "Invoke-RangerWizard requires an interactive host. Use Invoke-AzureLocalRanger with a config file in non-interactive sessions."
        )
    }

    # ── helpers ────────────────────────────────────────────────────────────────
    function Prompt-WizardValue {
        param([string]$Label, [string]$Default, [switch]$Secret)
        $prompt = if ($Default) { "$Label [$Default]" } else { $Label }
        if ($Secret) {
            $raw = Read-Host -Prompt $prompt -AsSecureString
            if ($raw.Length -eq 0 -and $Default) { return $Default }
            return $raw
        }
        $raw = Read-Host -Prompt $prompt
        if ([string]::IsNullOrWhiteSpace($raw) -and $Default) { return $Default }
        return $raw
    }

    function Prompt-WizardList {
        param([string]$Label, [string]$Hint)
        $raw = Read-Host -Prompt "$Label (comma-separated$Hint)"
        if ([string]::IsNullOrWhiteSpace($raw)) { return @() }
        return @($raw -split '\s*,\s*' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    }

    # ── banner ─────────────────────────────────────────────────────────────────
    Write-Host ''
    Write-Host '  ╔══════════════════════════════════════╗' -ForegroundColor Cyan
    Write-Host '  ║   AzureLocalRanger — Setup Wizard    ║' -ForegroundColor Cyan
    Write-Host '  ╚══════════════════════════════════════╝' -ForegroundColor Cyan
    Write-Host '  Press Enter to accept the default shown in [brackets].' -ForegroundColor Gray
    Write-Host ''

    # ── Section 1: Environment ─────────────────────────────────────────────────
    Write-Host '── Environment ──────────────────────────' -ForegroundColor DarkCyan
    $envName     = Prompt-WizardValue -Label 'Environment name (short label)'  -Default 'prod-azlocal-01'
    $clusterName = Prompt-WizardValue -Label 'Cluster name (CNO / display name)' -Default "$envName"
    $clusterFqdn = Prompt-WizardValue -Label 'Cluster FQDN or NetBIOS name (leave blank to skip)'

    # ── Section 2: Nodes ──────────────────────────────────────────────────────
    Write-Host ''
    Write-Host '── Cluster Nodes ────────────────────────' -ForegroundColor DarkCyan
    $clusterNodes = Prompt-WizardList -Label 'Node FQDNs' -Hint ', e.g. node01.lab.local,node02.lab.local'

    # ── Section 3: Azure ──────────────────────────────────────────────────────
    Write-Host ''
    Write-Host '── Azure Integration (optional) ─────────' -ForegroundColor DarkCyan
    $subscriptionId = Prompt-WizardValue -Label 'Subscription ID (GUID, blank to skip)'
    $tenantId       = Prompt-WizardValue -Label 'Tenant ID (GUID, blank to skip)'
    $resourceGroup  = Prompt-WizardValue -Label 'Resource group name'

    # ── Section 4: Credentials ────────────────────────────────────────────────
    Write-Host ''
    Write-Host '── Credentials ──────────────────────────' -ForegroundColor DarkCyan
    Write-Host '  Credential strategy options:' -ForegroundColor Gray
    Write-Host '    [1] Use current session context (default)' -ForegroundColor Gray
    Write-Host '    [2] Prompt at run time' -ForegroundColor Gray
    $credStrategy = Prompt-WizardValue -Label 'Credential strategy' -Default '1'

    $clusterUsername = ''
    $domainUsername  = ''
    if ($credStrategy -eq '2') {
        $clusterUsername = Prompt-WizardValue -Label 'Cluster WinRM username (DOMAIN\\user)'
        $domainUsername  = Prompt-WizardValue -Label 'Domain username (DOMAIN\\user, blank = same as cluster)'
    }

    # ── Section 5: Output ─────────────────────────────────────────────────────
    Write-Host ''
    Write-Host '── Output ───────────────────────────────' -ForegroundColor DarkCyan
    $outputPath    = Prompt-WizardValue -Label 'Output root path' -Default 'C:\AzureLocalRanger'
    $formatsRaw    = Prompt-WizardValue -Label 'Report formats [html,markdown,docx,xlsx,pdf,svg,drawio]' -Default 'html,markdown,docx,xlsx,pdf,svg'
    $reportFormats = @($formatsRaw -split '\s*,\s*' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })

    # ── Section 6: Scope ──────────────────────────────────────────────────────
    Write-Host ''
    Write-Host '── Collection Scope ─────────────────────' -ForegroundColor DarkCyan
    Write-Host '  Available domains: clusterNode, hardware, storage, networking, virtualMachines,' -ForegroundColor Gray
    Write-Host '    identitySecurity, azureIntegration, monitoring, managementTools, performance, oemIntegration' -ForegroundColor Gray
    $includeDomains = Prompt-WizardList -Label 'Include only these domains' -Hint ', blank = all'
    $excludeDomains = Prompt-WizardList -Label 'Exclude these domains' -Hint ', blank = none'

    # ── Assemble config ────────────────────────────────────────────────────────
    $wizardConfig = [ordered]@{
        environment = [ordered]@{
            name        = $envName
            clusterName = $clusterName
            description = "Generated by Invoke-RangerWizard on $(Get-Date -Format 'yyyy-MM-dd')"
        }
        targets = [ordered]@{
            cluster = [ordered]@{
                fqdn  = $clusterFqdn
                nodes = $clusterNodes
            }
            azure = [ordered]@{
                subscriptionId = $subscriptionId
                resourceGroup  = $resourceGroup
                tenantId       = $tenantId
            }
            bmc = [ordered]@{ endpoints = @() }
        }
        credentials = [ordered]@{
            azure = [ordered]@{ method = 'existing-context' }
        }
        domains = [ordered]@{
            include = $includeDomains
            exclude = $excludeDomains
        }
        output = [ordered]@{
            mode         = 'current-state'
            formats      = $reportFormats
            rootPath     = $outputPath
            showProgress = $true
        }
        behavior = [ordered]@{
            promptForMissingCredentials = ($credStrategy -eq '2')
            degradationMode             = 'graceful'
            transport                   = 'auto'
        }
    }

    if ($credStrategy -eq '2') {
        if (-not [string]::IsNullOrWhiteSpace($clusterUsername)) {
            $wizardConfig.credentials['cluster'] = [ordered]@{ username = $clusterUsername }
        }
        if (-not [string]::IsNullOrWhiteSpace($domainUsername)) {
            $wizardConfig.credentials['domain'] = [ordered]@{ username = $domainUsername }
        }
    }

    # ── Save choice ────────────────────────────────────────────────────────────
    Write-Host ''
    Write-Host '── What would you like to do? ───────────' -ForegroundColor DarkCyan
    Write-Host '    [S] Save configuration only' -ForegroundColor Gray
    Write-Host '    [R] Run immediately (without saving)' -ForegroundColor Gray
    Write-Host '    [B] Both — save and run' -ForegroundColor Gray
    $action = (Prompt-WizardValue -Label 'Choice' -Default 'B').ToUpper().Trim()
    if ($SkipRun -and $action -ne 'S') { $action = 'S' }

    $savedPath = $null
    if ($action -in @('S', 'B')) {
        $saveTo = if (-not [string]::IsNullOrWhiteSpace($OutputConfigPath)) {
            $OutputConfigPath
        } else {
            Prompt-WizardValue -Label 'Save config to path' -Default "C:\AzureLocalRanger\$envName-ranger.yml"
        }
        $resolvedSave = Resolve-RangerPath -Path $saveTo
        New-Item -ItemType Directory -Path (Split-Path -Parent $resolvedSave) -Force | Out-Null
        $wizardConfig | ConvertTo-Json -Depth 50 | Set-Content -Path $resolvedSave -Encoding UTF8
        $savedPath = $resolvedSave
        Write-Host "  Configuration saved: $resolvedSave" -ForegroundColor Green
    }

    if ($action -in @('R', 'B')) {
        Write-Host ''
        Write-Host '  Launching AzureLocalRanger…' -ForegroundColor Cyan
        $runParams = @{ ConfigObject = $wizardConfig; ShowProgress = $true }
        Invoke-AzureLocalRanger @runParams
    }
    else {
        Write-Host ''
        Write-Host "  Run 'Invoke-AzureLocalRanger -ConfigPath $savedPath' when ready." -ForegroundColor Gray
    }
}
