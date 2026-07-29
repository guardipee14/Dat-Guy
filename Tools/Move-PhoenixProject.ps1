[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$ProjectRoot = (Resolve-Path "$PSScriptRoot\..").Path
)

$ErrorActionPreference = 'Stop'

function Ensure-Folder {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        New-Item -ItemType Directory -Path $Path | Out-Null
    }
}

function Move-PhoenixFile {

    param(
        [string]$Source,
        [string]$Destination
    )

    if (-not (Test-Path $Source)) {
        return
    }

    $destinationFolder = Split-Path $Destination

    Ensure-Folder $destinationFolder

    if (Get-Command git -ErrorAction SilentlyContinue) {

        Push-Location $ProjectRoot

        git mv $Source $Destination

        Pop-Location

    }
    else {

        Move-Item `
            -Path $Source `
            -Destination $Destination `
            -Force

    }

}

$Folders = @(
    "Classes\Base",
    "Classes\Core",
    "Classes\Models",
    "Classes\Providers",
    "Private\Backup",
    "Private\Restore",
    "Build",
    "Docs",
    "Tests",
    "Tools"
)

foreach ($Folder in $Folders) {

    Ensure-Folder (Join-Path $ProjectRoot $Folder)

}

Move-PhoenixFile `
    "Classes\Driver.ps1" `
    "Classes\Base\Driver.ps1"

Move-PhoenixFile `
    "Classes\Package.ps1" `
    "Classes\Base\Package.ps1"

Move-PhoenixFile `
    "Classes\Result.ps1" `
    "Classes\Base\Result.ps1"

    Move-PhoenixFile `
    "Classes\PhoenixContext.ps1" `
    "Classes\Core\PhoenixContext.ps1"

Move-PhoenixFile `
    "Classes\PhoenixLogger.ps1" `
    "Classes\Core\PhoenixLogger.ps1"

Move-PhoenixFile `
    "Classes\PackageCandidate.ps1" `
    "Classes\Models\PackageCandidate.ps1"

Get-ChildItem `
    "$ProjectRoot\Classes" `
    -Filter PhoenixManifest.ps1 `
    -Recurse