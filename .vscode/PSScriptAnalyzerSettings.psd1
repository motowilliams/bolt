@{
    # PSScriptAnalyzer settings for Gosh build system
    # https://github.com/PowerShell/PSScriptAnalyzer

    # Exclude PSAvoidUsingWriteHost for build orchestration scripts
    # Write-Host is intentionally used for user-facing build output with colors
    # Exclude PSUseBOMForUnicodeEncodedFile to maintain UTF-8 without BOM
    # (consistent with .editorconfig charset = utf-8)
    # Exclude PSReviewUnusedParameter for argument completer scriptblocks
    # (PowerShell passes all 5 parameters by signature, even if not all are used)
    ExcludeRules = @(
        'PSAvoidUsingWriteHost',
        'PSUseBOMForUnicodeEncodedFile'
    )

    # Include all default rules except the ones above
    IncludeDefaultRules = $true

    # Severity levels to check
    Severity = @(
        'Error',
        'Warning',
        'Information'
    )
}
