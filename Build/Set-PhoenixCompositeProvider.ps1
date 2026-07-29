[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [ValidateSet(
        'PhoenixProvider',
        'WinGetProvider',
        'ChocolateyProvider'
    )]
    [string]$ProviderName,

    [Parameter()]
    [switch]$Disable
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ProjectRoot = (
    Resolve-Path (
        Join-Path $PSScriptRoot '..'
    )
).Path

$providerRoot = Join-Path `
    $ProjectRoot `
    "Classes\20-Providers\$ProviderName"

$markerPath = Join-Path `
    $providerRoot `
    '.composite-ready'

if (-not (Test-Path -LiteralPath $providerRoot)) {
    throw "Provider fragment folder not found: $providerRoot"
}

if ($Disable) {

    if (
        (Test-Path -LiteralPath $markerPath) -and
        $PSCmdlet.ShouldProcess(
            $markerPath,
            'Disable composite provider'
        )
    ) {

        Remove-Item `
            -LiteralPath $markerPath `
            -Force
    }

    Write-Host (
        "$ProviderName will use its legacy provider file."
    ) -ForegroundColor Yellow

    return
}

$headerPath = Join-Path `
    $providerRoot `
    "$ProviderName.Header.ps1"

$footerPath = Join-Path `
    $providerRoot `
    "$ProviderName.Footer.ps1"

$methodsRoot = Join-Path `
    $providerRoot `
    'Methods'

foreach ($requiredPath in @(
    $headerPath
    $footerPath
    $methodsRoot
)) {

    if (-not (Test-Path -LiteralPath $requiredPath)) {
        throw "Missing required composite path: $requiredPath"
    }
}

[string]$headerText =
    Get-Content `
        -LiteralPath $headerPath `
        -Raw

if (
    $headerText -notmatch (
        '(?m)^\s*class\s+{0}\b' -f
        [regex]::Escape($ProviderName)
    )
) {

    throw (
        "Header does not declare class '$ProviderName': " +
        $headerPath
    )
}

[string[]]$footerCodeLines = @(
    Get-Content `
        -LiteralPath $footerPath |
    Where-Object {
        $line = $_.Trim()

        -not [string]::IsNullOrWhiteSpace($line) -and
        -not $line.StartsWith('#')
    }
)

if (
    $footerCodeLines.Count -eq 0 -or
    $footerCodeLines[-1].Trim() -ne '}'
) {

    throw (
        'Footer must end with one class-closing brace: ' +
        $footerPath
    )
}

$methodFiles = @(
    Get-ChildItem `
        -LiteralPath $methodsRoot `
        -Filter '*.ps1' `
        -File `
        -Recurse
)

$methodCodeFiles = @(
    foreach ($methodFile in $methodFiles) {

        [string[]]$codeLines = @(
            Get-Content `
                -LiteralPath $methodFile.FullName |
            Where-Object {
                $line = $_.Trim()

                -not [string]::IsNullOrWhiteSpace($line) -and
                -not $line.StartsWith('#')
            }
        )

        if ($codeLines.Count -gt 0) {
            $methodFile
        }
    }
)

if ($methodCodeFiles.Count -eq 0) {

    throw (
        "No implemented method fragments were found for " +
        "$ProviderName."
    )
}

if (
    $PSCmdlet.ShouldProcess(
        $markerPath,
        'Enable composite provider'
    )
) {

    Set-Content `
        -LiteralPath $markerPath `
        -Value (
            "Enabled $(Get-Date -Format o)"
        ) `
        -Encoding utf8
}

Write-Host (
    "$ProviderName will now use its composite fragments."
) -ForegroundColor Green

Write-Host (
    'Run .\Build\Build-PhoenixClasses.ps1 to validate it.'
) -ForegroundColor Cyan
