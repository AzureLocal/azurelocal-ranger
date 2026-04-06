function Invoke-AzureLocalRanger {
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
        [switch]$NoRender
    )

    $credentialOverrides = @{
        cluster = $ClusterCredential
        domain  = $DomainCredential
        bmc     = $BmcCredential
    }

    Invoke-RangerDiscoveryRuntime -ConfigPath $ConfigPath -ConfigObject $ConfigObject -OutputPath $OutputPath -CredentialOverrides $credentialOverrides -IncludeDomains $IncludeDomain -ExcludeDomains $ExcludeDomain -NoRender:$NoRender
}

function New-AzureLocalRangerConfig {
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

    $config = Get-RangerDefaultConfig
    New-Item -ItemType Directory -Path (Split-Path -Parent $resolvedPath) -Force | Out-Null
    if ($Format -eq 'json') {
        $config | ConvertTo-Json -Depth 50 | Set-Content -Path $resolvedPath -Encoding UTF8
    }
    else {
        (ConvertTo-RangerYaml -InputObject $config) -join [Environment]::NewLine | Set-Content -Path $resolvedPath -Encoding UTF8
    }

    Get-Item -Path $resolvedPath
}

function Export-AzureLocalRangerReport {
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

    $manifest = Get-Content -Path $resolvedManifestPath -Raw | ConvertFrom-Json -Depth 100
    $packageRoot = if ($OutputPath) { Resolve-RangerPath -Path $OutputPath } else { Split-Path -Parent $resolvedManifestPath }
    Invoke-RangerOutputGeneration -Manifest (ConvertTo-RangerHashtable -InputObject $manifest) -PackageRoot $packageRoot -Formats $Formats -Mode $manifest.run.mode
}

function Test-AzureLocalRangerPrerequisites {
    [CmdletBinding()]
    param(
        [string]$ConfigPath,
        $ConfigObject
    )

    $config = Import-RangerConfiguration -ConfigPath $ConfigPath -ConfigObject $ConfigObject
    $validation = Test-RangerConfiguration -Config $config -PassThru
    $selectedCollectors = Resolve-RangerSelectedCollectors -Config $config
    $checks = @(
        [ordered]@{ Name = 'PowerShell 7+'; Passed = $PSVersionTable.PSVersion.Major -ge 7; Detail = $PSVersionTable.PSVersion.ToString() },
        [ordered]@{ Name = 'WinRM cmdlets'; Passed = (Test-RangerCommandAvailable -Name 'Invoke-Command'); Detail = 'Invoke-Command' },
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