function Get-PhoenixDriver {

    [CmdletBinding()]
    param()

    Write-PhoenixLog -Level Info -Message "Enumerating installed drivers."

    Get-CimInstance Win32_PnPSignedDriver | ForEach-Object {

        $driver = [Driver]::new()

        $driver.Name         = $_.DeviceName
        $driver.Manufacturer = $_.Manufacturer
        $driver.Version      = $_.DriverVersion
        $driver.Provider     = $_.DriverProviderName
        $driver.InfName      = $_.InfName
        $driver.Present      = $true

        $driver

    }

}