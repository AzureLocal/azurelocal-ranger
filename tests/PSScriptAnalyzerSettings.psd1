# Looser settings for the Pester suites (tests build SecureStrings from literals and use fixed computer names on purpose).
@{
    Severity     = @('Error', 'Warning')
    ExcludeRules = @(
        'PSAvoidUsingWriteHost',
        'PSUseBOMForUnicodeEncodedFile',
        'PSUseSingularNouns',
        'PSUseShouldProcessForStateChangingFunctions',
        'PSUseOutputTypeCorrectly',
        'PSReviewUnusedParameter',
        'PSAvoidUsingPositionalParameters',
        # Test fixtures create SecureString/PSCredential values from literals; there is no secret in the repo.
        'PSAvoidUsingConvertToSecureStringWithPlainText',
        # Mocks and parameter-filter tests name computers explicitly.
        'PSAvoidUsingComputerNameHardcoded',
        # Pester variables are assigned in BeforeAll / It scopes and read in other blocks; the analyzer cannot see that.
        'PSUseDeclaredVarsMoreThanAssignments',
        'PSAvoidUsingEmptyCatchBlock',
        # Mocks and fixtures name parameters TestCredential / Credential and declare them untyped; none holds a real secret.
        'PSAvoidUsingPlainTextForPassword',
        'PSUsePSCredentialType',
        # Test helpers set and read script / global state across Pester blocks.
        'PSAvoidGlobalVars'
    )
}
