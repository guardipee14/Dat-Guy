using module '..\Classes\Phoenix.Classes.psm1'

function New-PhoenixBootableIso {

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$WorkspacePath,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$OutputPath,

        [Parameter()]
        [AllowEmptyString()]
        [string]$OscdimgPath = ''
    )

    $info = Get-PhoenixWinPEWorkspaceOwnedInfo -Path $WorkspacePath

    if ($info.Workspace.State -ne 'Ready') {
        throw "WinPE workspace must be Ready before ISO creation; current state is '$($info.Workspace.State)'."
    }

    if ([string]::IsNullOrWhiteSpace($OscdimgPath)) {
        $readiness = Get-PhoenixDeploymentPrerequisite
        $tool = @($readiness.Tools | Where-Object Name -eq 'Oscdimg') | Select-Object -First 1
        $OscdimgPath = [string]$tool.Path
    }

    [IO.FileInfo]$oscdimg = Get-Item -LiteralPath $OscdimgPath -Force -ErrorAction Stop

    if ($oscdimg -isnot [IO.FileInfo] -or ($oscdimg.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw "Oscdimg must be a regular file: $OscdimgPath"
    }

    [string]$resolvedOutput = [IO.Path]::GetFullPath($OutputPath)
    Test-PhoenixPathAncestors -Path $resolvedOutput
    Test-PhoenixPathAncestors -Path $oscdimg.FullName
    if ($resolvedOutput.StartsWith($info.RootPath.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) {
        throw 'ISO output must be outside the input workspace.'
    }
    $inventory = @(Get-PhoenixBootMediaInventory -MediaPath $info.Workspace.MediaPath)

    if (Test-Path -LiteralPath $resolvedOutput) {
        throw "Bootable ISO output already exists: $resolvedOutput"
    }

    [string]$biosBoot = Join-Path $info.Workspace.MediaPath 'fwfiles\etfsboot.com'
    [string]$uefiBoot = Join-Path $info.Workspace.MediaPath 'fwfiles\efisys.bin'
    if (-not (Test-Path -LiteralPath $biosBoot -PathType Leaf)) {
        $biosBoot = Join-Path $oscdimg.DirectoryName 'etfsboot.com'
    }
    if (-not (Test-Path -LiteralPath $uefiBoot -PathType Leaf)) {
        $uefiBoot = Join-Path $oscdimg.DirectoryName 'efisys.bin'
    }

    foreach ($bootFile in @($biosBoot, $uefiBoot)) {
        Test-PhoenixPathAncestors -Path $bootFile
        if (-not (Test-Path -LiteralPath $bootFile -PathType Leaf)) {
            throw "WinPE media is missing required boot file: $bootFile"
        }
    }

    if (-not $PSCmdlet.ShouldProcess($resolvedOutput, "Build bootable WinPE ISO from '$($info.RootPath)'")) {
        return [pscustomobject]@{
            Path = $resolvedOutput
            WorkspaceId = $info.Workspace.WorkspaceId
            Created = $false
            Sha256 = ''
            Length = 0
        }
    }

    $null = New-Item -ItemType Directory -Path (Split-Path -Path $resolvedOutput -Parent) -Force -ErrorAction Stop
    [string]$bootData = "-bootdata:2#p0,e,b$biosBoot#pEF,e,b$uefiBoot"
    # Reserve the output exclusively so an existing/concurrently created ISO is never overwritten.
    $reservation = [IO.File]::Open($resolvedOutput, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    $reservation.Dispose()
    try {
    $toolResult = Invoke-PhoenixExternalTool -FilePath $oscdimg.FullName -ArgumentList @('-m', '-o', '-u2', '-udfver102', '-t01/01/2020,00:00:00', $bootData, $info.Workspace.MediaPath, $resolvedOutput)

    if ($toolResult.ExitCode -ne 0) {
        throw ('Oscdimg failed: ' + ($toolResult.Output -join [Environment]::NewLine))
    }

    [IO.FileInfo]$iso = Get-Item -LiteralPath $resolvedOutput -Force -ErrorAction Stop

    if ($iso.Length -le 0) {
        throw 'Oscdimg produced an empty ISO image.'
    }

    foreach ($record in $inventory) {
        $source = Join-Path $info.Workspace.MediaPath $record.RelativePath
        if ((Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash -cne $record.Sha256) {
            throw 'WinPE media changed while the ISO was being built.'
        }
    }

    return [pscustomobject]@{
        Path = $iso.FullName
        WorkspaceId = $info.Workspace.WorkspaceId
        Created = $true
        Sha256 = (Get-FileHash -LiteralPath $iso.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        Length = $iso.Length
    }
    }
    catch {
        Remove-Item -LiteralPath $resolvedOutput -Force -ErrorAction SilentlyContinue
        throw
    }
}
