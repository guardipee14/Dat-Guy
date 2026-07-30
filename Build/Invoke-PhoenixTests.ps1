[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet(
        'None',
        'Normal',
        'Detailed',
        'Diagnostic'
    )]
    [string]$Output = 'Detailed',

    [Parameter()]
    [switch]$CodeCoverage
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = (
    Resolve-Path (
        Join-Path `
            $PSScriptRoot `
            '..'
    )
).Path

$testsRoot =
    Join-Path `
        $projectRoot `
        'Tests'

if (-not (Test-Path -LiteralPath $testsRoot)) {
    throw "Phoenix tests folder was not found: $testsRoot"
}

$pesterModule = @(
    Get-Module `
        -Name Pester `
        -ListAvailable |
        Where-Object {
            $_.Version -ge [version]'6.0.0'
        } |
        Sort-Object Version -Descending
) |
    Select-Object -First 1

if ($null -eq $pesterModule) {
    throw (
        'Pester 6.0.0 or later is required. ' +
        'Install it for the current user before running Phoenix tests.'
    )
}

Get-Module `
    -Name Pester |
    Remove-Module `
        -Force `
        -ErrorAction SilentlyContinue

Import-Module `
    -Name $pesterModule.Path `
    -Force `
    -ErrorAction Stop

$artifactRoot =
    Join-Path `
        $projectRoot `
        'Artifacts\Pester'

$null = New-Item `
    -ItemType Directory `
    -Path $artifactRoot `
    -Force

$configuration =
    New-PesterConfiguration

$configuration.Run.Path =
    @($testsRoot)

$configuration.Run.PassThru =
    $true

$configuration.Output.Verbosity =
    $Output

$configuration.Should.DisableV5 =
    $true

$configuration.Should.ErrorAction =
    'Stop'

$configuration.TestResult.Enabled =
    $true

$configuration.TestResult.OutputFormat =
    'NUnitXml'

$configuration.TestResult.OutputPath =
    Join-Path `
        $artifactRoot `
        'TestResults.xml'

if ($CodeCoverage) {

    $configuration.CodeCoverage.Enabled =
        $true

    $configuration.CodeCoverage.Path = @(
        Join-Path `
            $projectRoot `
            'Private\Core\Get-PhoenixPropertyValue.ps1'

        Join-Path `
            $projectRoot `
            'Private\Packages\Test-PhoenixRestorePackage.ps1'
    )

    $configuration.CodeCoverage.OutputFormat =
        'Cobertura'

    $configuration.CodeCoverage.OutputPath =
        Join-Path `
            $artifactRoot `
            'Coverage.xml'

    # Fail the coverage run if the focused unit-test baseline regresses.
    $configuration.CodeCoverage.CoveragePercentTarget =
        90
}

$result =
    Invoke-Pester `
        -Configuration $configuration

$summaryColor = if ($result.Result -eq 'Passed') {
    'Green'
}
else {
    'Red'
}

Write-Host ''
Write-Host (
    'Phoenix tests: {0} passed, {1} failed, {2} skipped.' -f
    $result.PassedCount,
    $result.FailedCount,
    $result.SkippedCount
) -ForegroundColor $summaryColor

if ($result.Result -ne 'Passed') {
    throw (
        'Phoenix Pester regression tests failed. ' +
        "See '$artifactRoot' for the test report."
    )
}

return $result