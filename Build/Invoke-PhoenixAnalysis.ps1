[CmdletBinding()]
param(
    [Parameter()]
    [switch]$Strict
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot =
    [IO.Path]::GetFullPath(
        (
            Join-Path `
                $PSScriptRoot `
                '..'
        )
    )

$minimumAnalyzerVersion = [version]'1.25.0'

$analyzerModule =
    Get-Module `
        -Name PSScriptAnalyzer `
        -ListAvailable |
        Where-Object {
            $_.Version -ge $minimumAnalyzerVersion
        } |
        Sort-Object Version -Descending |
        Select-Object -First 1

if ($null -eq $analyzerModule) {
    throw (
        (
            'PSScriptAnalyzer {0} or later is required. Run ' +
            "'.\Build\Install-DeveloperTools.ps1' first."
        ) -f $minimumAnalyzerVersion
    )
}

Get-Module `
    -Name PSScriptAnalyzer |
    Remove-Module `
        -Force `
        -ErrorAction SilentlyContinue

Import-Module `
    -Name $analyzerModule.Path `
    -Force `
    -ErrorAction Stop

$analysisFiles = @(
    Get-Item `
        -LiteralPath @(
            (
                Join-Path `
                    $projectRoot `
                    'Build.ps1'
            )
            (
                Join-Path `
                    $projectRoot `
                    'Phoenix.psm1'
            )
            (
                Join-Path `
                    $projectRoot `
                    'Phoenix.psd1'
            )
        )

    foreach (
        $relativeRoot in @(
            'Private'
            'Public'
            'Build'
            'Tools'
            'Tests'
        )
    ) {

        $analysisRoot =
            Join-Path `
                $projectRoot `
                $relativeRoot

        if (-not (Test-Path -LiteralPath $analysisRoot)) {
            continue
        }

        Get-ChildItem `
            -LiteralPath $analysisRoot `
            -Recurse `
            -File |
            Where-Object {
                $_.Extension -in @(
                    '.ps1'
                    '.psm1'
                    '.psd1'
                ) -and
                $_.FullName -notmatch (
                    '[\\/]Build[\\/]MigrationBackups[\\/]'
                )
            }
    }
) |
    Sort-Object `
        -Property FullName `
        -Unique

$analysisFindings = @(
    foreach ($file in $analysisFiles) {
        Invoke-ScriptAnalyzer `
            -Path $file.FullName `
            -Severity @(
                'Error'
                'Warning'
            )
    }
)

$securityRuleNames = @(
    'PSAvoidGlobalVars'
    'PSAvoidUsingConvertToSecureStringWithPlainText'
    'PSAvoidUsingInvokeExpression'
    'PSAvoidUsingPlainTextForPassword'
    'PSAvoidUsingUsernameAndPasswordParams'
    'PSUsePSCredentialType'
)

$blockingFindings = @(
    $analysisFindings |
        Where-Object {
            $Strict -or
            $_.Severity.ToString() -eq 'Error' -or
            $_.RuleName -in $securityRuleNames
        }
)

$errorCount = @(
    $analysisFindings |
        Where-Object {
            $_.Severity.ToString() -eq 'Error'
        }
).Count

$warningCount = @(
    $analysisFindings |
        Where-Object {
            $_.Severity.ToString() -eq 'Warning'
        }
).Count

$reportDirectory =
    Join-Path `
        $projectRoot `
        'Artifacts\PSScriptAnalyzer'

if (-not (Test-Path -LiteralPath $reportDirectory)) {
    New-Item `
        -ItemType Directory `
        -Path $reportDirectory `
        -Force |
        Out-Null
}

$reportPath =
    Join-Path `
        $reportDirectory `
        'AnalysisResults.json'

$findingRecords = @(
    $analysisFindings |
        ForEach-Object {
            [ordered]@{
                Severity   = $_.Severity.ToString()
                RuleName   = $_.RuleName
                ScriptPath = $_.ScriptPath
                ScriptName = $_.ScriptName
                Line       = $_.Line
                Column     = $_.Column
                Message    = $_.Message
            }
        }
)

$report = [ordered]@{
    GeneratedAtUtc       = (
        Get-Date
    ).ToUniversalTime().ToString('o')
    AnalyzerVersion      = $analyzerModule.Version.ToString()
    Strict               = [bool]$Strict
    ProjectRoot          = $projectRoot
    FileCount            = $analysisFiles.Count
    FindingCount         = $analysisFindings.Count
    ErrorCount           = $errorCount
    WarningCount         = $warningCount
    BlockingFindingCount = $blockingFindings.Count
    SecurityRules        = $securityRuleNames
    Findings             = $findingRecords
}

$report |
    ConvertTo-Json -Depth 8 |
    Set-Content `
        -LiteralPath $reportPath `
        -Encoding UTF8

Write-Information `
    -MessageData '' `
    -InformationAction Continue

Write-Information `
    -MessageData (
        'PSScriptAnalyzer {0} analyzed {1} files.' -f
        $analyzerModule.Version,
        $analysisFiles.Count
    ) `
    -InformationAction Continue

Write-Information `
    -MessageData (
        (
            'Findings: {0} total, {1} errors, {2} warnings, ' +
            '{3} blocking.'
        ) -f
            $analysisFindings.Count,
            $errorCount,
            $warningCount,
            $blockingFindings.Count
    ) `
    -InformationAction Continue

if ($analysisFindings.Count -gt 0) {

    $findingSummary =
        $analysisFindings |
        Group-Object `
            -Property @(
                'Severity'
                'RuleName'
            ) |
        Sort-Object Count -Descending |
        Select-Object -Property @(
            'Count'
            @{
                Name = 'Severity'
                Expression = {
                    $_.Group[0].Severity
                }
            }
            @{
                Name = 'RuleName'
                Expression = {
                    $_.Group[0].RuleName
                }
            }
        ) |
        Format-Table -AutoSize |
        Out-String

    Write-Information `
        -MessageData $findingSummary.TrimEnd() `
        -InformationAction Continue
}

if ($blockingFindings.Count -gt 0) {

    $blockingPreview =
        $blockingFindings |
        Select-Object -First 25 |
        Select-Object -Property @(
            'Severity'
            'RuleName'
            'ScriptName'
            'Line'
            'Message'
        ) |
        Format-Table -Wrap -AutoSize |
        Out-String

    Write-Information `
        -MessageData '' `
        -InformationAction Continue

    Write-Information `
        -MessageData 'Blocking analyzer findings:' `
        -InformationAction Continue

    Write-Information `
        -MessageData $blockingPreview.TrimEnd() `
        -InformationAction Continue

    throw (
        (
            'Phoenix static analysis failed with {0} blocking finding(s). ' +
            "See '{1}' for the complete report."
        ) -f
            $blockingFindings.Count,
            $reportPath
    )
}

return [pscustomobject]@{
    Success              = $true
    AnalyzerVersion      = $analyzerModule.Version.ToString()
    Strict               = [bool]$Strict
    FileCount            = $analysisFiles.Count
    FindingCount         = $analysisFindings.Count
    ErrorCount           = $errorCount
    WarningCount         = $warningCount
    BlockingFindingCount = $blockingFindings.Count
    ReportPath           = $reportPath
}