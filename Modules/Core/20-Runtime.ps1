function Invoke-RangerCollectorExecution {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Definition,

        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Config,

        [Parameter(Mandatory = $true)]
        $CredentialMap,

        [Parameter(Mandatory = $true)]
        [string]$PackageRoot
    )

    $messages = New-Object System.Collections.Generic.List[string]
    $start = (Get-Date).ToUniversalTime().ToString('o')
    $status = 'success'
    $functionName = $Definition.FunctionName
    $arguments = @{
        Config       = $Config
        CredentialMap = $CredentialMap
        Definition   = $Definition
        PackageRoot  = $PackageRoot
    }

    try {
        if (-not (Get-Command -Name $functionName -ErrorAction SilentlyContinue)) {
            throw "Collector function '$functionName' is not available."
        }

        $result = & $functionName @arguments
        if (-not $result) {
            $status = 'not-applicable'
            $result = @{}
        }
        elseif ($result.Status) {
            $status = $result.Status
        }

        $messages.Add("Collector '$($Definition.Id)' completed with status '$status'.")
    }
    catch {
        $status = if ($Definition.Class -eq 'optional' -and [bool]$Config.behavior.skipUnavailableOptionalDomains) { 'skipped' } else { 'failed' }
        $messages.Add($_.Exception.Message)
        $result = @{
            Domains       = @{}
            Findings      = @(
                New-RangerFinding -Severity warning -Title "Collector $($Definition.Id) did not complete" -Description $_.Exception.Message -CurrentState $status -Recommendation 'Review target reachability, credentials, and required dependencies.'
            )
            Relationships = @()
            Evidence      = @()
        }
    }

    $end = (Get-Date).ToUniversalTime().ToString('o')
    return @{
        CollectorId     = $Definition.Id
        Status          = $status
        StartTimeUtc    = $start
        EndTimeUtc      = $end
        TargetScope     = @($Definition.RequiredTargets)
        CredentialScope = $Definition.RequiredCredential
        Messages        = @($messages + @($result.Messages))
        Domains         = if ($result.Domains) { $result.Domains } else { @{} }
        Topology        = $result.Topology
        Relationships   = @($result.Relationships)
        Findings        = @($result.Findings)
        Evidence        = @($result.Evidence)
        RawEvidence     = $result.RawEvidence
    }
}

function New-RangerPackageRoot {
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Config,

        [string]$OutputPathOverride,
        [string]$BasePath = (Get-Location).Path
    )

    $rootPath = if ($OutputPathOverride) { $OutputPathOverride } else { $Config.output.rootPath }
    $resolvedRoot = Resolve-RangerPath -Path $rootPath -BasePath $BasePath
    $packageName = '{0}-{1}-{2}' -f (Get-RangerSafeName -Value ($Config.environment.name)), (Get-RangerSafeName -Value $Config.output.mode), (Get-RangerTimestamp)
    $packageRoot = Join-Path -Path $resolvedRoot -ChildPath $packageName
    New-Item -ItemType Directory -Path $packageRoot -Force | Out-Null
    return $packageRoot
}

function Invoke-RangerDiscoveryRuntime {
    param(
        [string]$ConfigPath,
        $ConfigObject,
        [string]$OutputPath,
        [hashtable]$CredentialOverrides,
        [string[]]$IncludeDomains,
        [string[]]$ExcludeDomains,
        [switch]$NoRender,
        [hashtable]$StructuralOverrides,
        [switch]$AllowInteractiveInput
    )

    $config = Import-RangerConfiguration -ConfigPath $ConfigPath -ConfigObject $ConfigObject
    $config = Set-RangerStructuralOverrides -Config $config -StructuralOverrides $StructuralOverrides

    if ($IncludeDomains) {
        $config.domains.include = @($IncludeDomains)
    }

    if ($ExcludeDomains) {
        $config.domains.exclude = @($ExcludeDomains)
    }

    if ($AllowInteractiveInput) {
        $config = Invoke-RangerInteractiveInput -Config $config
    }

    $script:RangerLogLevel = Resolve-RangerLogLevel -Level $(if ($config.behavior.logLevel) { $config.behavior.logLevel } else { 'info' })
    $script:RangerBehaviorRetryCount = if ($config.behavior.retryCount -gt 0) { [int]$config.behavior.retryCount } else { 0 }
    $validation = Test-RangerConfiguration -Config $config -PassThru
    if (-not $validation.IsValid) {
        throw ($validation.Errors -join [Environment]::NewLine)
    }

    $selectedCollectors = Resolve-RangerSelectedCollectors -Config $config
    $credentialMap = Resolve-RangerCredentialMap -Config $config -Overrides $CredentialOverrides
    $basePath = if ($ConfigPath) { Split-Path -Parent (Resolve-RangerPath -Path $ConfigPath) } else { (Get-Location).Path }
    $packageRoot = New-RangerPackageRoot -Config $config -OutputPathOverride $OutputPath -BasePath $basePath
    $script:RangerLogPath = $null
    $script:RangerRetryDetails = New-Object System.Collections.ArrayList
    $script:RangerWinRmProbeCache = @{}
    $logPath = Initialize-RangerFileLog -PackageRoot $packageRoot
    $transcriptPath = Join-Path -Path $packageRoot -ChildPath 'ranger.transcript.log'
    $script:_rangerPrevVerbosePreference = $VerbosePreference
    $script:_rangerPrevDebugPreference = $DebugPreference
    $script:_rangerPrevInformationPreference = $InformationPreference
    $script:_rangerPrevProgressPreference = $ProgressPreference

    switch ($script:RangerLogLevel) {
        'debug' {
            $VerbosePreference = 'Continue'
            $DebugPreference = 'Continue'
            $InformationPreference = 'Continue'
            $ProgressPreference = 'Continue'
        }
        'info' {
            $VerbosePreference = 'SilentlyContinue'
            $DebugPreference = 'SilentlyContinue'
            $InformationPreference = 'SilentlyContinue'
            $ProgressPreference = 'SilentlyContinue'
        }
        'warn' {
            $VerbosePreference = 'SilentlyContinue'
            $DebugPreference = 'SilentlyContinue'
            $InformationPreference = 'SilentlyContinue'
            $ProgressPreference = 'SilentlyContinue'
        }
        'error' {
            $VerbosePreference = 'SilentlyContinue'
            $DebugPreference = 'SilentlyContinue'
            $InformationPreference = 'SilentlyContinue'
            $ProgressPreference = 'SilentlyContinue'
        }
    }

    # Install a global Write-Warning proxy so warnings from ANY module (Az, WinRM, S2D, etc.) are
    # captured in the run log for the duration of this run, then restored in the finally block.
    $script:_rangerPrevWriteWarning = Get-Item function:\global:Write-Warning -ErrorAction SilentlyContinue
    function global:Write-Warning {
        param([AllowNull()][object]$Message)

        $messageText = ConvertTo-RangerLogMessage -InputObject $Message
        $currentLevel = Resolve-RangerLogLevel -Level $(if ($script:RangerLogLevel) { $script:RangerLogLevel } else { 'info' })
        if ((Get-RangerLogLevelRank -Level 'warn') -ge (Get-RangerLogLevelRank -Level $currentLevel) -and -not [string]::IsNullOrWhiteSpace($messageText) -and $script:RangerLogPath) {
            try {
                Add-Content -LiteralPath $script:RangerLogPath -Value "[$((Get-Date).ToString('s'))][WARN] $messageText" -Encoding UTF8 -ErrorAction Stop
            }
            catch {
            }
        }

        Microsoft.PowerShell.Utility\Write-Warning -Message $messageText
    }

    try {
        try {
            Start-Transcript -Path $transcriptPath -Force -ErrorAction Stop | Out-Null
        }
        catch {
            Write-RangerLog -Level warn -Message "Transcript start failed: $($_.Exception.Message)"
        }

        Write-RangerLog -Level info -Message "AzureLocalRanger run started — package: $(Split-Path -Leaf $packageRoot)"
        $manifest = New-RangerManifest -Config $config -SelectedCollectors $selectedCollectors
        $manifest.run.retryDetails = @()
        $manifestPath = Join-Path -Path $packageRoot -ChildPath 'manifest\audit-manifest.json'
        $evidenceRoot = Join-Path -Path $packageRoot -ChildPath 'evidence'

        foreach ($collector in $selectedCollectors) {
            Write-RangerLog -Level info -Message "Collector '$($collector.Id)' starting"
            $collectorResult = Invoke-RangerCollectorExecution -Definition $collector -Config $config -CredentialMap $credentialMap -PackageRoot $packageRoot
            Write-RangerLog -Level info -Message "Collector '$($collector.Id)' completed with status '$($collectorResult.Status)'"
            Add-RangerCollectorToManifest -Manifest ([ref]$manifest) -CollectorResult $collectorResult -EvidenceRoot $evidenceRoot -KeepRawEvidence ([bool]$config.output.keepRawEvidence)
        }

        $manifest.run.retryDetails = @($script:RangerRetryDetails)

        $manifestValidation = Test-RangerManifestSchema -Manifest $manifest -SelectedCollectors $selectedCollectors
        $manifest.run.schemaValidation = [ordered]@{
            isValid  = $manifestValidation.IsValid
            errors   = @($manifestValidation.Errors)
            warnings = @($manifestValidation.Warnings)
        }

        if ($manifestValidation.Warnings.Count -gt 0) {
            $manifest.findings += @(
                New-RangerFinding -Severity informational -Title 'Manifest schema warnings were recorded' -Description 'The generated manifest passed core validation but recorded schema warnings that should be reviewed before handoff.' -CurrentState ($manifestValidation.Warnings -join '; ') -Recommendation 'Review duplicate artifact paths or incomplete metadata before packaging the deliverable.'
            )
        }

        if (-not $manifestValidation.IsValid) {
            $manifest.findings += @(
                New-RangerFinding -Severity warning -Title 'Manifest schema validation failed' -Description 'The generated manifest did not satisfy the minimum schema contract for Ranger outputs.' -CurrentState ($manifestValidation.Errors -join '; ') -Recommendation 'Correct the collector payload or manifest contract before treating this package as a handoff-ready deliverable.'
            )
        }

        Save-RangerManifest -Manifest $manifest -Path $manifestPath
        $manifest.artifacts += @(New-RangerArtifactRecord -Type 'manifest-json' -RelativePath ([System.IO.Path]::GetRelativePath($packageRoot, $manifestPath)) -Status generated -Audience 'all')

        if (-not $manifestValidation.IsValid -and [bool]$config.behavior.failOnSchemaViolation) {
            Save-RangerManifest -Manifest $manifest -Path $manifestPath
            throw ($manifestValidation.Errors -join [Environment]::NewLine)
        }

        if (-not $NoRender -and [bool]$config.behavior.continueToRendering) {
            $renderResult = Invoke-RangerOutputGeneration -Manifest $manifest -PackageRoot $packageRoot -Formats @($config.output.formats) -Mode $config.output.mode
            if ($renderResult.Artifacts) {
                $manifest.artifacts += @($renderResult.Artifacts)
            }
            Save-RangerManifest -Manifest $manifest -Path $manifestPath
        }

        $packageIndexPath = New-RangerPackageIndex -Manifest $manifest -ManifestPath $manifestPath -PackageRoot $packageRoot
        $manifest.artifacts += @(New-RangerArtifactRecord -Type 'package-index' -RelativePath ([System.IO.Path]::GetRelativePath($packageRoot, $packageIndexPath)) -Status generated -Audience 'all')

        if ($logPath -and (Test-Path -LiteralPath $logPath)) {
            Write-RangerLog -Level info -Message "Run complete — package: $(Split-Path -Leaf $packageRoot)"
            $manifest.artifacts += @(New-RangerArtifactRecord -Type 'run-log' -RelativePath ([System.IO.Path]::GetRelativePath($packageRoot, $logPath)) -Status generated -Audience 'all')
        }

        Save-RangerManifest -Manifest $manifest -Path $manifestPath

        [ordered]@{
            Config       = $config
            Manifest     = $manifest
            ManifestPath = $manifestPath
            PackageRoot  = $packageRoot
            LogPath      = $logPath
            Validation   = $validation
            ManifestSchema = $manifestValidation
        }
    }
    finally {
        try {
            Stop-Transcript | Out-Null
        }
        catch {
        }

        if ($logPath -and (Test-Path -LiteralPath $logPath) -and (Test-Path -LiteralPath $transcriptPath)) {
            try {
                Add-Content -LiteralPath $logPath -Value @('', '# Host transcript', '') -Encoding UTF8 -ErrorAction Stop
                Get-Content -LiteralPath $transcriptPath -ErrorAction Stop | Add-Content -LiteralPath $logPath -Encoding UTF8 -ErrorAction Stop
            }
            catch {
            }
        }

        # Restore whatever Write-Warning existed before the run (usually the built-in)
        if ($script:_rangerPrevWriteWarning) {
            Set-Item function:\global:Write-Warning -Value $script:_rangerPrevWriteWarning.ScriptBlock
        } else {
            Remove-Item function:\global:Write-Warning -ErrorAction SilentlyContinue
        }
        $VerbosePreference = $script:_rangerPrevVerbosePreference
        $DebugPreference = $script:_rangerPrevDebugPreference
        $InformationPreference = $script:_rangerPrevInformationPreference
        $ProgressPreference = $script:_rangerPrevProgressPreference
        $script:RangerLogPath = $null
        $script:RangerRetryDetails = $null
        $script:RangerWinRmProbeCache = $null
        $script:RangerBehaviorRetryCount = $null
    }
}