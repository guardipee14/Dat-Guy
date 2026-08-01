using module '..\Classes\Phoenix.Classes.psm1'

function Save-PhoenixRestoreCheckpoint {
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([PhoenixRestoreCheckpoint])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [PhoenixRestoreCheckpoint]$Checkpoint,

        [Parameter()]
        [AllowEmptyString()]
        [string]$CheckpointRoot = ''
    )

    process {
        [guid]$sessionGuid = [guid]::Empty
        if (-not [guid]::TryParse($Checkpoint.SessionId, [ref]$sessionGuid)) {
            throw 'Checkpoint SessionId must be a GUID.'
        }
        if ([string]::IsNullOrWhiteSpace($CheckpointRoot)) {
            $context = Resolve-PhoenixContext -SkipProviderBootstrap -ErrorAction Stop
            $CheckpointRoot = $context.CheckpointRoot
        }
        [string]$resolvedRoot = [IO.Path]::GetFullPath($CheckpointRoot)
        [string]$sessionRoot = Join-Path $resolvedRoot $sessionGuid.ToString()
        [string]$currentPath = Join-Path $sessionRoot 'checkpoint.json'
        if (-not $PSCmdlet.ShouldProcess($currentPath, 'Save restore checkpoint')) {
            $Checkpoint.StoragePath = $currentPath
            return $Checkpoint
        }
        $null = New-Item -ItemType Directory -Path $sessionRoot -Force
        $Checkpoint.Sequence++
        $Checkpoint.UpdatedAtUtc = [datetime]::UtcNow
        $Checkpoint.StoragePath = $currentPath
        [string]$snapshotPath = Join-Path `
            $sessionRoot `
            ('checkpoint-{0:D6}.json' -f $Checkpoint.Sequence)
        [string]$temporaryPath = "$currentPath.$([guid]::NewGuid().ToString('N')).tmp"
        try {
            $Checkpoint | ConvertTo-Json -Depth 30 | Set-Content `
                -LiteralPath $temporaryPath -Encoding UTF8 -ErrorAction Stop
            Copy-Item -LiteralPath $temporaryPath -Destination $snapshotPath `
                -ErrorAction Stop
            Move-Item -LiteralPath $temporaryPath -Destination $currentPath `
                -Force -ErrorAction Stop
        }
        finally {
            Remove-Item -LiteralPath $temporaryPath -Force -ErrorAction SilentlyContinue
        }
        return $Checkpoint
    }
}
