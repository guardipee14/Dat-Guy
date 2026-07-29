[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$')]
    [string]$Version,

    [Parameter()]
    [switch]$Push
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Invoke-Git {

    param(
        [Parameter(Mandatory)]
        [string[]]$Arguments,

        [switch]$AllowFailure
    )

    $output = @(
        & git @Arguments 2>&1
    )

    $exitCode = $LASTEXITCODE

    if (
        -not $AllowFailure -and
        $exitCode -ne 0
    ) {
        throw (
            "Git command failed: git {0}`n{1}" -f
            ($Arguments -join ' '),
            ($output -join [Environment]::NewLine)
        )
    }

    return [pscustomobject]@{
        ExitCode = $exitCode
        Output   = $output
    }
}

function Get-GitValue {

    param(
        [Parameter(Mandatory)]
        [string[]]$Arguments
    )

    $result = Invoke-Git `
        -Arguments $Arguments `
        -AllowFailure

    if (
        $result.ExitCode -ne 0 -or
        $result.Output.Count -eq 0
    ) {
        return $null
    }

    return [string]$result.Output[0]
}

$repositoryRoot = Get-GitValue `
    -Arguments @(
        'rev-parse',
        '--show-toplevel'
    )

if ([string]::IsNullOrWhiteSpace($repositoryRoot)) {
    throw 'Run this script from inside the Phoenix Git repository.'
}

$repositoryRoot = $repositoryRoot.Trim()
Push-Location $repositoryRoot

try {

    $workingStatus = Invoke-Git `
        -Arguments @(
            'status',
            '--porcelain'
        )

    if ($workingStatus.Output.Count -gt 0) {
        throw (
            'Commit or discard existing changes before publishing a release.'
        )
    }

    $tagName = "v$Version"

    $existingTag = Get-GitValue `
        -Arguments @(
            'tag',
            '--list',
            $tagName
        )

    if (-not [string]::IsNullOrWhiteSpace($existingTag)) {
        throw "The Git tag '$tagName' already exists."
    }

    $manifestPath =
        Join-Path $repositoryRoot 'Phoenix.psd1'

    if (-not (Test-Path -LiteralPath $manifestPath)) {
        throw 'Phoenix.psd1 was not found at the repository root.'
    }

    $manifestText = Get-Content `
        -LiteralPath $manifestPath `
        -Raw

    if ($manifestText -notmatch "ModuleVersion\s*=\s*'[^']+'") {
        throw 'ModuleVersion was not found in Phoenix.psd1.'
    }

    $manifestText =
        $manifestText -replace
            "ModuleVersion\s*=\s*'[^']+'",
            "ModuleVersion = '$Version'"

    Set-Content `
        -LiteralPath $manifestPath `
        -Value $manifestText `
        -Encoding UTF8

    $changelogPath =
        Join-Path $repositoryRoot 'CHANGELOG.md'

    if (-not (Test-Path -LiteralPath $changelogPath)) {
        throw 'CHANGELOG.md was not found at the repository root.'
    }

    $changelogText = Get-Content `
        -LiteralPath $changelogPath `
        -Raw

    if ($changelogText -notmatch '(?m)^## \[Unreleased\]\s*$') {
        throw 'CHANGELOG.md does not contain an [Unreleased] section.'
    }

    $releaseDate = Get-Date -Format 'yyyy-MM-dd'

    $replacement = @"
## [Unreleased]

## [$Version] - $releaseDate
"@

    $changelogText =
        [regex]::Replace(
            $changelogText,
            '(?m)^## \[Unreleased\]\s*$',
            $replacement,
            1
        )

    Set-Content `
        -LiteralPath $changelogPath `
        -Value $changelogText `
        -Encoding UTF8

    $tokens = $null
    $parseErrors = $null

    [System.Management.Automation.Language.Parser]::ParseFile(
        $manifestPath,
        [ref]$tokens,
        [ref]$parseErrors
    ) | Out-Null

    if (@($parseErrors).Count -gt 0) {

        $parseErrors |
            Select-Object `
                @{Name = 'Line'; Expression = {
                    $_.Extent.StartLineNumber
                }},
                Message |
            Format-Table -AutoSize |
            Out-Host

        throw 'Phoenix.psd1 failed syntax validation.'
    }

    Invoke-Git `
        -Arguments @(
            'add',
            'Phoenix.psd1',
            'CHANGELOG.md'
        ) |
        Out-Null

    Invoke-Git `
        -Arguments @(
            'commit',
            '-m',
            "release: $tagName"
        ) |
        Select-Object -ExpandProperty Output |
        ForEach-Object {
            Write-Host $_
        }

    Invoke-Git `
        -Arguments @(
            'tag',
            '-a',
            $tagName,
            '-m',
            "Phoenix $tagName"
        ) |
        Out-Null

    Write-Host (
        'Created release commit and tag {0}.' -f
        $tagName
    ) -ForegroundColor Green

    if ($Push) {

        Invoke-Git `
            -Arguments @(
                'push'
            ) |
            Select-Object -ExpandProperty Output |
            ForEach-Object {
                Write-Host $_
            }

        Invoke-Git `
            -Arguments @(
                'push',
                'origin',
                $tagName
            ) |
            Select-Object -ExpandProperty Output |
            ForEach-Object {
                Write-Host $_
            }

        Write-Host 'Release commit and tag pushed successfully.' `
            -ForegroundColor Green
    }
}
finally {
    Pop-Location
}