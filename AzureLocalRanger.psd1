@{
    RootModule        = 'AzureLocalRanger.psm1'
    ModuleVersion     = '0.2.0'
    CompatiblePSEditions = @('Desktop', 'Core')
    GUID              = '8bc325c2-9b7f-46f9-b102-ef29e92a15b8'
    Author            = 'Azure Local Cloud'
    CompanyName       = 'Azure Local Cloud'
    Copyright         = '(c) 2026 Azure Local Cloud. All rights reserved.'
    Description       = 'Azure Local Ranger is a PowerShell module for documenting, auditing, and producing as-built outputs for Azure Local environments, including the on-prem platform, hosted workloads, and Azure resources tied to the deployment.'
    PowerShellVersion = '7.0'
    FunctionsToExport = @(
        'Invoke-AzureLocalRanger',
        'New-AzureLocalRangerConfig',
        'Export-AzureLocalRangerReport',
        'Test-AzureLocalRangerPrerequisites'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    PrivateData = @{
        PSData = @{
            Tags = @(
                'AzureLocal',
                'AzureStackHCI',
                'Arc',
                'PowerShell',
                'Documentation',
                'Inventory',
                'Audit',
                'AsBuilt'
            )
            LicenseUri = 'https://github.com/azure-local-cloud/azurelocal-ranger/blob/main/LICENSE'
            ProjectUri = 'https://github.com/azure-local-cloud/azurelocal-ranger'
            ReleaseNotes = 'Adds the initial Ranger runtime, grouped collectors, manifest persistence, and cached output generation for reports and diagrams.'
        }
    }
}