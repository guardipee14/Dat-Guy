using module '.\Classes\Phoenix.Classes.psm1'

Import-Module '.\Phoenix.psd1' -Force

[enum]::GetNames([PhoenixInstallMode])

Start-Phoenix

$providers = (Get-PhoenixContext).Providers

$providers |
    Select-Object `
        Name,
        Available,
        SupportsSilentInstall,
        SupportsInteractiveInstall,
        RequiredPrivilege |
    Format-Table

    $winget = $providers |
    Where-Object Name -eq 'WinGet'

$chocolatey = $providers |
    Where-Object Name -eq 'Chocolatey'

$winget.GetType().GetMethods() |
    Where-Object Name -eq 'InstallPackage' |
    ForEach-Object {
        $_.ToString()
    }

$winget |
    Get-Member -Name `
        CanInstallSilently,
        InstallPackageSilent,
        InstallPackageInteractive

$chocolatey |
    Get-Member -Name `
        CanInstallSilently,
        InstallPackageSilent,
        InstallPackageInteractive