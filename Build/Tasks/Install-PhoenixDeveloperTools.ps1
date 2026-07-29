function Install-PhoenixDeveloperTools {

    [CmdletBinding()]
    param()

    $modules = @(
        'PSScriptAnalyzer',
        'Pester',
        'platyPS'
    )

    foreach ($module in $modules) {

        Write-Host "Checking $module..." -ForegroundColor Cyan

        if (-not (Get-Module -ListAvailable -Name $module)) {

            Write-Host "Installing $module..." -ForegroundColor Yellow

            try {
                Install-Module -Name $module `
                    -Scope CurrentUser `
                    -Force `
                    -AllowClobber `
                    -ErrorAction Stop

                Write-Host "$module installed." -ForegroundColor Green
            }
            catch {
                Write-Host "Failed to install $module" -ForegroundColor Red
                throw
            }
        }
        else {
            Write-Host "$module already installed." -ForegroundColor Green
        }
    }
}