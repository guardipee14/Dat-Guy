function Initialize-PhoenixLogging {

    [CmdletBinding()]
    param()

    $Today = Get-Date

    $Folder = Join-Path `
        $script:PhoenixContext.ProjectRoot `
        ("Logs\{0}\{1}\{2}" -f `
            $Today.Year,
            $Today.ToString("MM"),
            $Today.ToString("dd"))

    if (!(Test-Path $Folder))
    {
        New-Item `
            -ItemType Directory `
            -Path $Folder `
            -Force | Out-Null
    }

    $LogName = "Phoenix-{0}.log" -f `
        $Today.ToString("HHmmss")

    $script:PhoenixContext.LogPath = $Folder

    $script:PhoenixContext.LogFile = Join-Path `
        $Folder `
        $LogName

}