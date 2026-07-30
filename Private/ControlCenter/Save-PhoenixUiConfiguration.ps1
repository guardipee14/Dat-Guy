function Save-PhoenixUiConfiguration {

    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [object]$Configuration
    )

    [string]$configurationPath =
        Get-PhoenixUiConfigurationPath

    if (
        -not $PSCmdlet.ShouldProcess(
            $configurationPath,
            'Save Phoenix UI configuration'
        )
    ) {
        return $configurationPath
    }

    [string]$configurationDirectory =
        Split-Path `
            -Path $configurationPath `
            -Parent

    if (
        -not (
            Test-Path `
                -LiteralPath $configurationDirectory
        )
    ) {
        New-Item `
            -ItemType Directory `
            -Path $configurationDirectory `
            -Force |
            Out-Null
    }

    [string]$temporaryPath = (
        '{0}.{1}.tmp' -f
        $configurationPath,
        [guid]::NewGuid().ToString('N')
    )

    try {
        $Configuration |
            ConvertTo-Json `
                -Depth 12 |
            Set-Content `
                -LiteralPath $temporaryPath `
                -Encoding UTF8 `
                -ErrorAction Stop

        Move-Item `
            -LiteralPath $temporaryPath `
            -Destination $configurationPath `
            -Force `
            -ErrorAction Stop
    }
    finally {
        if (Test-Path -LiteralPath $temporaryPath) {
            Remove-Item `
                -LiteralPath $temporaryPath `
                -Force `
                -ErrorAction SilentlyContinue
        }
    }

    return $configurationPath
}
