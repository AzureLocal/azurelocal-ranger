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

        # Issue #115: structural overrides — any of these win over the config file value
        [string]$ClusterFqdn,
        [string[]]$ClusterNodes,
        [string]$EnvironmentName,
        [string]$SubscriptionId,
        [string]$TenantId,
        [string]$ResourceGroup
    )

    $credentialOverrides = @{
        cluster = $ClusterCredential
        domain  = $DomainCredential
        bmc     = $BmcCredential
    }

    $structuralOverrides = @{}
    if ($PSBoundParameters.ContainsKey('ClusterFqdn'))     { $structuralOverrides['ClusterFqdn']     = $ClusterFqdn }
    if ($PSBoundParameters.ContainsKey('ClusterNodes'))    { $structuralOverrides['ClusterNodes']    = $ClusterNodes }
    if ($PSBoundParameters.ContainsKey('EnvironmentName')) { $structuralOverrides['EnvironmentName'] = $EnvironmentName }
    if ($PSBoundParameters.ContainsKey('SubscriptionId'))  { $structuralOverrides['SubscriptionId']  = $SubscriptionId }
    if ($PSBoundParameters.ContainsKey('TenantId'))        { $structuralOverrides['TenantId']        = $TenantId }
    if ($PSBoundParameters.ContainsKey('ResourceGroup'))   { $structuralOverrides['ResourceGroup']   = $ResourceGroup }

    Invoke-RangerDiscoveryRuntime -ConfigPath $ConfigPath -ConfigObject $ConfigObject -OutputPath $OutputPath -CredentialOverrides $credentialOverrides -IncludeDomains $IncludeDomain -ExcludeDomains $ExcludeDomain -NoRender:$NoRender -StructuralOverrides $structuralOverrides -AllowInteractiveInput
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

    $config = Import-RangerConfiguration -ConfigPath $ConfigPath -ConfigObject $ConfigObject
    $structuralOverrides = @{}
    if ($PSBoundParameters.ContainsKey('ClusterFqdn'))     { $structuralOverrides['ClusterFqdn']     = $ClusterFqdn }
    if ($PSBoundParameters.ContainsKey('ClusterNodes'))    { $structuralOverrides['ClusterNodes']    = $ClusterNodes }
    if ($PSBoundParameters.ContainsKey('EnvironmentName')) { $structuralOverrides['EnvironmentName'] = $EnvironmentName }
    if ($PSBoundParameters.ContainsKey('SubscriptionId'))  { $structuralOverrides['SubscriptionId']  = $SubscriptionId }
    if ($PSBoundParameters.ContainsKey('TenantId'))        { $structuralOverrides['TenantId']        = $TenantId }
    if ($PSBoundParameters.ContainsKey('ResourceGroup'))   { $structuralOverrides['ResourceGroup']   = $ResourceGroup }
    $config = Set-RangerStructuralOverrides -Config $config -StructuralOverrides $structuralOverrides
    $validation = Test-RangerConfiguration -Config $config -PassThru
    $selectedCollectors = Resolve-RangerSelectedCollectors -Config $config
    $checks = @(
        [ordered]@{ Name = 'PowerShell 7+'; Passed = $PSVersionTable.PSVersion.Major -ge 7; Detail = $PSVersionTable.PSVersion.ToString() },
        [ordered]@{ Name = 'WinRM cmdlets'; Passed = (Test-RangerCommandAvailable -Name 'Invoke-Command'); Detail = 'Invoke-Command' },
        [ordered]@{ Name = 'RSAT AD'; Passed = (Test-RangerCommandAvailable -Name 'Get-ADUser'); Detail = 'Get-ADUser (required for identity domain collection)' },
        [ordered]@{ Name = 'Cluster cmdlets'; Passed = (Test-RangerCommandAvailable -Name 'Get-Cluster'); Detail = 'Get-Cluster (optional on the runner, required on cluster nodes)' },
        [ordered]@{ Name = 'Hyper-V cmdlets'; Passed = (Test-RangerCommandAvailable -Name 'Get-VM'); Detail = 'Get-VM (optional on the runner, required on cluster nodes)' },
        [ordered]@{ Name = 'Az modules'; Passed = (Test-RangerCommandAvailable -Name 'Get-AzContext'); Detail = 'Get-AzContext' },
        [ordered]@{ Name = 'Azure CLI'; Passed = (Test-RangerCommandAvailable -Name 'az'); Detail = 'az (optional fallback)' },
        [ordered]@{ Name = 'Pester'; Passed = (Test-RangerCommandAvailable -Name 'Invoke-Pester'); Detail = 'Invoke-Pester' }
    )

    [ordered]@{
        Validation         = $validation
        SelectedCollectors = @($selectedCollectors | ForEach-Object { $_.Id })
        Checks             = $checks
    }
}