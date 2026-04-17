# Azure Local Ranger root module

$moduleRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$moduleFolders = @(
    (Join-Path $moduleRoot 'Modules\Internal'),
    (Join-Path $moduleRoot 'Modules\Private'),
    (Join-Path $moduleRoot 'Modules\Core'),
    (Join-Path $moduleRoot 'Modules\Collectors'),
    (Join-Path $moduleRoot 'Modules\Outputs\Reports'),
    (Join-Path $moduleRoot 'Modules\Outputs\Templates'),
    (Join-Path $moduleRoot 'Modules\Outputs\Diagrams'),
    (Join-Path $moduleRoot 'Modules\Public')
)

foreach ($folder in $moduleFolders) {
    if (Test-Path -Path $folder) {
        Get-ChildItem -Path $folder -Filter '*.ps1' -File -ErrorAction SilentlyContinue |
            Sort-Object FullName |
            ForEach-Object { . $_.FullName }
    }
}

Export-ModuleMember -Function @(
    'Invoke-AzureLocalRanger',
    'New-AzureLocalRangerConfig',
    'Export-AzureLocalRangerReport',
    'Test-AzureLocalRangerPrerequisites',
    'Test-RangerPermissions',
    'Invoke-RangerWizard',
    # v2.0.0 (#226): WAF rule config hot-swap helpers.
    'Export-RangerWafConfig',
    'Import-RangerWafConfig',
    # v2.2.0 (#243): copy-pasteable remediation script generator.
    'Get-RangerRemediation'
)