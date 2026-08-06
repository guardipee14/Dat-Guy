[CmdletBinding()]
param(
    [Parameter()]
    [switch]$KeepGenerated
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ProjectRoot = (
    Resolve-Path (
        Join-Path $PSScriptRoot '..'
    )
).Path

$ClassesRoot = Join-Path `
    $ProjectRoot `
    'Classes'

$ProvidersRoot = Join-Path `
    $ClassesRoot `
    '20-Providers'

$GeneratedRoot = Join-Path `
    $ClassesRoot `
    'Generated'

$OutputPath = Join-Path `
    $ClassesRoot `
    'Phoenix.Classes.psm1'

if (
    (Test-Path -LiteralPath $GeneratedRoot) -and
    (-not $KeepGenerated)
) {

    Remove-Item `
        -LiteralPath $GeneratedRoot `
        -Recurse `
        -Force
}

$null = New-Item `
    -ItemType Directory `
    -Path $GeneratedRoot `
    -Force

$OutputLines =
    [System.Collections.Generic.List[string]]::new()

$LineMap =
    [System.Collections.Generic.List[object]]::new()

function Get-PhoenixRelativeClassPath {

    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $rootPath = (
        [IO.Path]::GetFullPath($ClassesRoot)
    ).TrimEnd([char[]]@('\', '/')) +
        [IO.Path]::DirectorySeparatorChar

    $fullPath = [IO.Path]::GetFullPath($Path)

    if (
        $fullPath.StartsWith(
            $rootPath,
            [StringComparison]::OrdinalIgnoreCase
        )
    ) {

        return $fullPath.Substring(
            $rootPath.Length
        )
    }

    return $fullPath
}

function Add-PhoenixSourceToOutput {

    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Missing class source file: $Path"
    }

    [string]$relativePath =
        Get-PhoenixRelativeClassPath `
            -Path $Path

    [string[]]$sourceLines =
        [IO.File]::ReadAllLines($Path)

    $OutputLines.Add(
        "#region $relativePath"
    )

    [int]$generatedStartLine =
        $OutputLines.Count + 1

    foreach ($sourceLine in $sourceLines) {
        $OutputLines.Add($sourceLine)
    }

    [int]$generatedEndLine =
        $OutputLines.Count

    $OutputLines.Add(
        "#endregion $relativePath"
    )

    $OutputLines.Add('')

    $LineMap.Add(
        [pscustomobject]@{
            SourcePath = $relativePath
            GeneratedStartLine = $generatedStartLine
            GeneratedEndLine = $generatedEndLine
        }
    )
}

function Get-PhoenixCompositeParts {

    param(
        [Parameter(Mandatory)]
        [string]$ProviderName
    )

    $providerRoot = Join-Path `
        $ProvidersRoot `
        $ProviderName

    $headerPath = Join-Path `
        $providerRoot `
        "$ProviderName.Header.ps1"

    $methodsRoot = Join-Path `
        $providerRoot `
        'Methods'

    $footerPath = Join-Path `
        $providerRoot `
        "$ProviderName.Footer.ps1"

    if (-not (Test-Path -LiteralPath $headerPath)) {
        throw "Missing composite header: $headerPath"
    }

    if (-not (Test-Path -LiteralPath $methodsRoot)) {
        throw "Missing composite methods folder: $methodsRoot"
    }

    if (-not (Test-Path -LiteralPath $footerPath)) {
        throw "Missing composite footer: $footerPath"
    }

    [string]$headerText =
        Get-Content `
            -LiteralPath $headerPath `
            -Raw

    [string]$classPattern = (
        '(?m)^\s*class\s+{0}\b' -f
        [regex]::Escape($ProviderName)
    )

    if ($headerText -notmatch $classPattern) {

        throw (
            "The composite header does not declare class " +
            "'$ProviderName': $headerPath"
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
            "The composite footer must end with one class-closing " +
            "brace: $footerPath"
        )
    }

    $methodFiles = @(
        Get-ChildItem `
            -LiteralPath $methodsRoot `
            -Filter '*.ps1' `
            -File `
            -Recurse |
        Sort-Object FullName
    )

    return @(
        $headerPath
        $methodFiles.FullName
        $footerPath
    )
}

function Write-PhoenixCompositeSnapshot {

    param(
        [Parameter(Mandatory)]
        [string]$ProviderName,

        [Parameter(Mandatory)]
        [string[]]$Parts
    )

    $snapshotPath = Join-Path `
        $GeneratedRoot `
        "$ProviderName.generated.ps1"

    $snapshotLines =
        [System.Collections.Generic.List[string]]::new()

    $snapshotLines.Add(
        "#region Composite class: $ProviderName"
    )

    $snapshotLines.Add('')

    foreach ($part in $Parts) {

        [string]$relativePath =
            Get-PhoenixRelativeClassPath `
                -Path $part

        $snapshotLines.Add(
            "#region $relativePath"
        )

        foreach (
            $line in [IO.File]::ReadAllLines($part)
        ) {
            $snapshotLines.Add($line)
        }

        $snapshotLines.Add(
            "#endregion $relativePath"
        )

        $snapshotLines.Add('')
    }

    $snapshotLines.Add(
        "#endregion Composite class: $ProviderName"
    )

    [IO.File]::WriteAllLines(
        $snapshotPath,
        $snapshotLines,
        [Text.UTF8Encoding]::new($true)
    )
}

function Add-PhoenixProvider {

    param(
        [Parameter(Mandatory)]
        [string]$ProviderName
    )

    $compositeRoot = Join-Path `
        $ProvidersRoot `
        $ProviderName

    $readyMarker = Join-Path `
        $compositeRoot `
        '.composite-ready'

    if (Test-Path -LiteralPath $readyMarker) {

        Write-Host (
            "Composite provider: $ProviderName"
        ) -ForegroundColor Cyan

        [string[]]$parts = @(
            Get-PhoenixCompositeParts `
                -ProviderName $ProviderName
        )

        Write-PhoenixCompositeSnapshot `
            -ProviderName $ProviderName `
            -Parts $parts

        foreach ($part in $parts) {
            Add-PhoenixSourceToOutput `
                -Path $part
        }

        return
    }

    $legacyPath = Join-Path `
        $ProvidersRoot `
        "$ProviderName.ps1"

    Write-Host (
        "Legacy provider: $ProviderName"
    ) -ForegroundColor DarkYellow

    Add-PhoenixSourceToOutput `
        -Path $legacyPath
}

function Add-PhoenixRelativeClassFile {

    param(
        [Parameter(Mandatory)]
        [string]$RelativePath
    )

    Add-PhoenixSourceToOutput `
        -Path (
            Join-Path `
                $ClassesRoot `
                $RelativePath
        )
}

$OutputLines.Add(
    '# -----------------------------------------------------------------'
)

$OutputLines.Add(
    '# AUTO-GENERATED FILE'
)

$OutputLines.Add(
    '# DO NOT EDIT'
)

$OutputLines.Add(
    '# -----------------------------------------------------------------'
)

$OutputLines.Add('')

$baseAndCoreFiles = @(
    '00-Base\PhoenixPrivilegeLevel.ps1'
    '00-Base\PhoenixInstallMode.ps1'
    '00-Base\PhoenixProviderOperation.ps1'
    '00-Base\PhoenixPackageAcquisitionStatus.ps1'
    '00-Base\PhoenixDeploymentOperation.ps1'
    '00-Base\PhoenixDeploymentCapability.ps1'
    '00-Base\PhoenixDeploymentDecision.ps1'
    '00-Base\PhoenixDeploymentResult.ps1'
    '00-Base\PhoenixContentAddress.ps1'
    '00-Base\PhoenixProviderAvailability.ps1'
    '00-Base\Result.ps1'
    '00-Base\PhoenixProviderCapability.ps1'
    '00-Base\PhoenixProviderResult.ps1'
    '00-Base\Package.ps1'
    '00-Base\EXEPackageDefinition.ps1'
    '00-Base\GitHubReleasePackageDefinition.ps1'
    '00-Base\PowerShellGalleryPackageDefinition.ps1'
    '00-Base\NuGetPackageDefinition.ps1'
    '00-Base\DISMPackageDefinition.ps1'
    '00-Base\WSUSPackageDefinition.ps1'
    '00-Base\Driver.ps1'
    '00-Base\PhoenixOemDriverUpdate.ps1'
    '00-Base\PhoenixOemDriverAdapter.ps1'
    '00-Base\DellOemDriverAdapter.ps1'
    '00-Base\HpOemDriverAdapter.ps1'
    '00-Base\LenovoOemDriverAdapter.ps1'
    '00-Base\IntelOemDriverAdapter.ps1'
    '00-Base\AmdOemDriverAdapter.ps1'
    '00-Base\NvidiaOemDriverAdapter.ps1'

    '10-Core\PhoenixLogger.ps1'
    '10-Core\PhoenixConfiguration.ps1'
    '10-Core\PhoenixBuild.ps1'
    '10-Core\PhoenixBackgroundOperation.ps1'
)

foreach ($relativePath in $baseAndCoreFiles) {

    Add-PhoenixRelativeClassFile `
        -RelativePath $relativePath
}

$partOneProviders = @(
    'PhoenixProvider'
    'WinGetProvider'
    'ChocolateyProvider'
    'ScoopProvider'
    'MSIProvider'
    'EXEProvider'
    'GitHubProvider'
    'PowerShellGalleryProvider'
    'NuGetProvider'
    'DISMProvider'
    'WSUSProvider'
)

foreach ($providerName in $partOneProviders) {

    Add-PhoenixProvider `
        -ProviderName $providerName
}

$modelFiles = @(
    '30-Models\PhoenixApplication.ps1'
    '30-Models\PhoenixActivityRecord.ps1'
    '30-Models\PhoenixInventory.ps1'
    '30-Models\PackageCandidate.ps1'
    '30-Models\PhoenixContentObject.ps1'
    '30-Models\PhoenixPackageAcquisitionRequest.ps1'
    '30-Models\PhoenixPackageAcquisitionResult.ps1'
    '30-Models\PhoenixOfflineBundleManifest.ps1'
    '30-Models\PhoenixManifest.ps1'
    '30-Models\PhoenixRestoreCheckpoint.ps1'
    '30-Models\PhoenixRestoreVerification.ps1'

    '10-Core\PhoenixContext.ps1'
)

foreach ($relativePath in $modelFiles) {

    Add-PhoenixRelativeClassFile `
        -RelativePath $relativePath
}

[IO.File]::WriteAllLines(
    $OutputPath,
    $OutputLines,
    [Text.UTF8Encoding]::new($true)
)

$tokens = $null
$parseErrors = $null

[Management.Automation.Language.Parser]::ParseFile(
    $OutputPath,
    [ref]$tokens,
    [ref]$parseErrors
) | Out-Null

if ($parseErrors.Count -gt 0) {

    $reportedErrors = foreach (
        $parseError in $parseErrors
    ) {

        [int]$generatedLine =
            $parseError.Extent.StartLineNumber

        $sourceEntry = $LineMap |
            Where-Object {
                $generatedLine -ge
                    $_.GeneratedStartLine -and
                $generatedLine -le
                    $_.GeneratedEndLine
            } |
            Select-Object -First 1

        if ($null -ne $sourceEntry) {

            [int]$sourceLine = (
                $generatedLine -
                $sourceEntry.GeneratedStartLine +
                1
            )

            [pscustomobject]@{
                GeneratedLine = $generatedLine
                SourceFile = $sourceEntry.SourcePath
                SourceLine = $sourceLine
                Message = $parseError.Message
            }
        }
        else {

            [pscustomobject]@{
                GeneratedLine = $generatedLine
                SourceFile = '<generated wrapper>'
                SourceLine = $null
                Message = $parseError.Message
            }
        }
    }

    Write-Host ''
    Write-Host (
        'Phoenix class generation failed validation:'
    ) -ForegroundColor Red

    $reportedErrors |
        Format-Table `
            GeneratedLine,
            SourceFile,
            SourceLine,
            Message `
            -AutoSize `
            -Wrap

    throw (
        'Phoenix.Classes.psm1 contains class errors.'
    )
}

Write-Host ''
Write-Host (
    "Generated and validated $OutputPath"
) -ForegroundColor Green

Write-Host (
    "Generated provider snapshots: $GeneratedRoot"
) -ForegroundColor DarkGray
