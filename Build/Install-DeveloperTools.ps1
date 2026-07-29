function Install-PhoenixDeveloperTools {

    [CmdletBinding()]
    param()

    $modules = @(
        'PSScriptAnalyzer',
        'Pester',
        'platyPS'
    )

    foreach ($module in $modules) {

        Write-Host "Checking $module..."

        if (-not (Get-Module -ListAvailable -Name $module)) {

            Write-Host "Installing $module..." -ForegroundColor Yellow

            Install-Module -Name $module `
                -Scope CurrentUser `
                -Force `
                -AllowClobber

            Write-Host "$module installed." -ForegroundColor Green
        }
        else {
            Write-Host "$module already installed." -ForegroundColor Green
        }
    }
}