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
        [switch]$NoRender
    )

    $config = Import-RangerConfiguration -ConfigPath $ConfigPath -ConfigObject $ConfigObject
    if ($IncludeDomains) {
        $config.domains.include = @($IncludeDomains)
    }

    if ($ExcludeDomains) {
        $config.domains.exclude = @($ExcludeDomains)
    }

    $script:RangerLogLevel = if ($config.behavior.logLevel) { $config.behavior.logLevel.ToLowerInvariant() } else { 'info' }
    $validation = Test-RangerConfiguration -Config $config -PassThru
    if (-not $validation.IsValid) {
        throw ($validation.Errors -join [Environment]::NewLine)
    }

    $selectedCollectors = Resolve-RangerSelectedCollectors -Config $config
    $credentialMap = Resolve-RangerCredentialMap -Config $config -Overrides $CredentialOverrides
    $basePath = if ($ConfigPath) { Split-Path -Parent (Resolve-RangerPath -Path $ConfigPath) } else { (Get-Location).Path }
    $packageRoot = New-RangerPackageRoot -Config $config -OutputPathOverride $OutputPath -BasePath $basePath
    $manifest = New-RangerManifest -Config $config -SelectedCollectors $selectedCollectors
    $manifestPath = Join-Path -Path $packageRoot -ChildPath 'manifest\audit-manifest.json'
    $evidenceRoot = Join-Path -Path $packageRoot -ChildPath 'evidence'

    foreach ($collector in $selectedCollectors) {
        $collectorResult = Invoke-RangerCollectorExecution -Definition $collector -Config $config -CredentialMap $credentialMap -PackageRoot $packageRoot
        Add-RangerCollectorToManifest -Manifest ([ref]$manifest) -CollectorResult $collectorResult -EvidenceRoot $evidenceRoot -KeepRawEvidence ([bool]$config.output.keepRawEvidence)
    }

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
    Save-RangerManifest -Manifest $manifest -Path $manifestPath

    [ordered]@{
        Config       = $config
        Manifest     = $manifest
        ManifestPath = $manifestPath
        PackageRoot  = $packageRoot
        Validation   = $validation
        ManifestSchema = $manifestValidation
    }
}