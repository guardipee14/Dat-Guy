function Install-PhoenixDriver {

    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        throw "Driver path not found: $Path"
    }

    if ($PSCmdlet.ShouldProcess($Path, "Install driver")) {

        Write-PhoenixLog `
            -Level Info `
            -Message "Installing driver from '$Path'."

        pnputil.exe /add-driver "$Path" /install

    }

}