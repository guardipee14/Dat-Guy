function Initialize-PhoenixScheduler {

    [CmdletBinding()]
    param()

    Write-PhoenixLog `
        -Level Info `
        -Message "Scheduler initialized."

    $script:PhoenixContext.Scheduler = [ordered]@{
        Enabled = $true
        Tasks   = @()
    }

}