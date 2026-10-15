# PSScriptAnalyzer settings for AzureLocalRanger (used by CI and by local runs):
#   Invoke-ScriptAnalyzer -Path . -Recurse -Settings ./PSScriptAnalyzerSettings.psd1
# Every excluded rule has a reason. Findings of the remaining rules must be fixed or suppressed in code with a justification.
@{
    Severity     = @('Error', 'Warning', 'Information')
    ExcludeRules = @(
        # Ranger is an interactive operator tool: console output (summaries, wizard prompts, credential prompts) is the design.
        'PSAvoidUsingWriteHost',
        # The repository convention is UTF-8 without BOM and PowerShell 7+ only (CompatiblePSEditions = Core), which reads it correctly.
        # Adding a BOM to every source file would rewrite the history of the whole module for no behavioural gain.
        'PSUseBOMForUnicodeEncodedFile',
        # Function names are the module's public and internal API surface (for example Get-RangerRemediation, Import-RangerManualEvidence);
        # renaming plural nouns is a breaking change with no benefit.
        'PSUseSingularNouns',
        # Internal helpers named New-/Set-/Update- only build in-memory objects or write inside the run package that the same run created.
        # The one exported cmdlet that writes a user-chosen file (New-AzureLocalRangerConfig) supports -WhatIf / -Confirm.
        'PSUseShouldProcessForStateChangingFunctions',
        # Informational: the module returns ordered dictionaries, which have no useful [OutputType]; adding it to ~75 functions is noise.
        'PSUseOutputTypeCorrectly',
        # Collectors share one signature (Config, CredentialMap, Definition, PackageRoot) so the runtime can call them uniformly, and
        # Azure query scriptblocks receive a fixed positional argument list; unused members of those fixed shapes are intentional.
        'PSReviewUnusedParameter',
        # New-RangerDesignRow is an internal row factory with a fixed eight-slot signature that the table-driven comparison calls about 30 times;
        # naming every slot at every call would hide the table.
        'PSAvoidUsingPositionalParameters'
    )
}
