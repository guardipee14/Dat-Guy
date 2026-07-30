function Initialize-PhoenixScheduler {

    [CmdletBinding()]
    param(
        [Parameter()]
        [AllowNull()]
        [PhoenixContext]$Context
    )

    Write-PhoenixLog `
        -Level Info `
        -Message "Scheduler initialized."

    $contextToInitialize = $Context

    if ($null -eq $contextToInitialize) {
        $contextToInitialize =
            Resolve-PhoenixContext
    }

    $contextToInitialize.Scheduler = [ordered]@{
        Enabled = $true
        Tasks   = @()
    }

}
