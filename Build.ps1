[CmdletBinding()]
param(
    [Parameter()]
    [switch]$SkipTests,

    [Parameter()]
    [switch]$CodeCoverage,

    [Parameter()]
    [switch]$KeepGenerated,

    [Parameter()]
    [ValidateSet(
        'None',
        'Normal',
        'Detailed',
        'Diagnostic'
    )]
    [string]$TestOutput = 'Detailed'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($SkipTests -and $CodeCoverage) {
    throw 'Code coverage cannot be enabled when tests are skipped.'
}

$buildStartedAt = Get-Date
$projectRoot = $PSScriptRoot

$classBuilder =
    Join-Path `
        $projectRoot `
        'Build\Build-PhoenixClasses.ps1'

$testRunner =
    Join-Path `
        $projectRoot `
        'Build\Invoke-PhoenixTests.ps1'

$moduleManifest =
    Join-Path `
        $projectRoot `
        'Phoenix.psd1'

foreach (
    $requiredPath in @(
        $classBuilder
        $moduleManifest
    )
) {

    if (-not (Test-Path -LiteralPath $requiredPath)) {
        throw "Required Phoenix build file was not found: $requiredPath"
    }
}

if (
    -not $SkipTests -and
    -not (Test-Path -LiteralPath $testRunner)
) {
    throw "Phoenix test runner was not found: $testRunner"
}

function Test-PhoenixModuleImport {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ManifestPath
    )

    $powerShellPath = $null

    try {
        $powerShellPath =
            (Get-Process -Id $PID -ErrorAction Stop).Path
    }
    catch {
        $powerShellPath = $null
    }

    if ([string]::IsNullOrWhiteSpace($powerShellPath)) {

        $powerShellCommand =
            Get-Command `
                -Name @(
                    'pwsh'
                    'powershell'
                ) `
                -ErrorAction SilentlyContinue |
                Select-Object -First 1

        if ($null -ne $powerShellCommand) {
            $powerShellPath = $powerShellCommand.Source
        }
    }

    if ([string]::IsNullOrWhiteSpace($powerShellPath)) {
        throw 'Unable to locate PowerShell for module validation.'
    }

    $validationScriptPath =
        Join-Path `
            ([IO.Path]::GetTempPath()) `
            (
                'Phoenix-BuildValidation-{0}.ps1' -f
                [guid]::NewGuid().ToString('N')
            )

    $validationScript = @'
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$ManifestPath
)

$ErrorActionPreference = 'Stop'
Import-Module -Name $ManifestPath -Force -ErrorAction Stop

if ($null -eq (Get-Module -Name Phoenix)) {
    throw 'Phoenix was not loaded after module import.'
}
'@

    Set-Content `
        -LiteralPath $validationScriptPath `
        -Value $validationScript `
        -Encoding UTF8

    $validationOutput = @()
    $validationExitCode = -1

    try {

        $validationOutput = @(
            & $powerShellPath `
                -NoLogo `
                -NoProfile `
                -NonInteractive `
                -File $validationScriptPath `
                -ManifestPath $ManifestPath `
                2>&1
        )

        $validationExitCode = $LASTEXITCODE
    }
    finally {

        Remove-Item `
            -LiteralPath $validationScriptPath `
            -Force `
            -ErrorAction SilentlyContinue
    }

    if ($validationExitCode -ne 0) {

        $message = @(
            'Phoenix module import validation failed.'
            ($validationOutput -join [Environment]::NewLine)
        ) -join [Environment]::NewLine

        throw $message
    }
}

Write-Host ''
Write-Host 'Starting Phoenix build...' `
    -ForegroundColor Cyan

Write-Host (
    'Project root: {0}' -f
    $projectRoot
) -ForegroundColor DarkGray

Write-Host ''
Write-Host 'Building Phoenix classes...' `
    -ForegroundColor Cyan

& $classBuilder `
    -KeepGenerated:$KeepGenerated

Test-ModuleManifest `
    -Path $moduleManifest `
    -ErrorAction Stop |
    Out-Null

Test-PhoenixModuleImport `
    -ManifestPath $moduleManifest

Write-Host 'Phoenix module import validation passed.' `
    -ForegroundColor Green

$testResult = $null

if (-not $SkipTests) {

    Write-Host ''
    Write-Host 'Running Phoenix regression tests...' `
        -ForegroundColor Cyan

    $testResult =
        & $testRunner `
            -Output $TestOutput `
            -CodeCoverage:$CodeCoverage
}
else {

    Write-Host ''
    Write-Host 'Phoenix regression tests were skipped.' `
        -ForegroundColor DarkYellow
}

$gitBranch = ''
$gitCommit = ''

$gitCommand =
    Get-Command `
        git `
        -ErrorAction SilentlyContinue

if ($null -ne $gitCommand) {

    $gitBranchOutput = @(
        & $gitCommand.Source `
            -C $projectRoot `
            branch `
            --show-current `
            2>$null
    )

    if ($LASTEXITCODE -eq 0) {
        $gitBranch =
            ($gitBranchOutput -join '').Trim()
    }

    $gitCommitOutput = @(
        & $gitCommand.Source `
            -C $projectRoot `
            rev-parse `
            --short `
            HEAD `
            2>$null
    )

    if ($LASTEXITCODE -eq 0) {
        $gitCommit =
            ($gitCommitOutput -join '').Trim()
    }
}

$elapsed =
    (Get-Date) - $buildStartedAt

$testCount = if ($null -ne $testResult) {
    $testResult.TotalCount
}
else {
    0
}

$passedCount = if ($null -ne $testResult) {
    $testResult.PassedCount
}
else {
    0
}

$coveragePercent = if (
    $null -ne $testResult -and
    $null -ne $testResult.CodeCoverage
) {
    [Math]::Round(
        $testResult.CodeCoverage.CoveragePercent,
        2
    )
}
else {
    $null
}

$summary = [pscustomobject]@{
    Success             = $true
    ProjectRoot         = $projectRoot
    ClassesGenerated    = $true
    ModuleValidated     = $true
    TestsRun            = -not [bool]$SkipTests
    TestCount           = $testCount
    PassedCount         = $passedCount
    CodeCoverageEnabled = [bool]$CodeCoverage
    CoveragePercent     = $coveragePercent
    GitBranch           = $gitBranch
    GitCommit           = $gitCommit
    DurationSeconds     = [Math]::Round(
        $elapsed.TotalSeconds,
        2
    )
}

Write-Host ''
Write-Host 'Phoenix build completed successfully.' `
    -ForegroundColor Green

if (
    -not [string]::IsNullOrWhiteSpace($gitBranch) -or
    -not [string]::IsNullOrWhiteSpace($gitCommit)
) {

    Write-Host (
        'Git: {0} @ {1}' -f
        $gitBranch,
        $gitCommit
    ) -ForegroundColor DarkGray
}

return $summary