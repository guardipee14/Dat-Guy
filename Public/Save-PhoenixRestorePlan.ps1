using module '..\Classes\Phoenix.Classes.psm1'

function Save-PhoenixRestorePlan {
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNull()]
        [object]$Plan,

        [Parameter(Mandatory)]
        [Alias('Path')]
        [ValidateNotNullOrEmpty()]
        [string]$LiteralPath
    )

    process {
        if ([string]$Plan.Schema -ne 'PhoenixRestorePlan') {
            throw 'Only a PhoenixRestorePlan can be saved.'
        }
        [string]$resolvedPath = if ([IO.Path]::IsPathRooted($LiteralPath)) {
            [IO.Path]::GetFullPath($LiteralPath)
        }
        else {
            [IO.Path]::GetFullPath((Join-Path (Get-Location).Path $LiteralPath))
        }
        if (-not $PSCmdlet.ShouldProcess($resolvedPath, 'Save Phoenix restore plan')) {
            return $resolvedPath
        }
        [string]$parent = Split-Path -Path $resolvedPath -Parent
        if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
            $null = New-Item -ItemType Directory -Path $parent -Force
        }
        [string]$temporaryPath = "$resolvedPath.$([guid]::NewGuid().ToString('N')).tmp"
        try {
            $Plan | ConvertTo-Json -Depth 30 | Set-Content `
                -LiteralPath $temporaryPath -Encoding UTF8 -ErrorAction Stop
            Move-Item -LiteralPath $temporaryPath -Destination $resolvedPath `
                -Force -ErrorAction Stop
        }
        finally {
            Remove-Item -LiteralPath $temporaryPath -Force -ErrorAction SilentlyContinue
        }
        return $resolvedPath
    }
}
