function Install-MissingProviders {

    [CmdletBinding()]
    param()

    Write-Host '>>> Install-MissingProviders executed <<<' -ForegroundColor DarkGray
    Write-Host ''

    $context = Get-PhoenixContext

    if ($null -eq $context) {

        Write-Warning 'Phoenix context is unavailable.'

        return
    }

    foreach ($provider in $context.Providers) {

        Write-Host "Checking $($provider.Name)..."

        try {

            $provider.Available = $provider.TestAvailable()
        }
        catch {

            $provider.Available = $false

            Write-Warning (
                "Availability check failed for {0}: {1}" -f
                $provider.Name,
                $_.Exception.Message
            )
        }

        if ($provider.Available) {

            Write-Host '  ✓ Already installed.' -ForegroundColor Green
            Write-Host ''

            continue
        }

        $hasRequiredPrivilege = Test-PhoenixPrivilege `
            -RequiredPrivilege $provider.RequiredPrivilege

        if (-not $hasRequiredPrivilege) {

            Write-Host (
                '  Administrator privileges are required to install {0}.' -f
                $provider.Name
            ) -ForegroundColor Yellow

            $elevationStarted = Request-PhoenixElevation `
                -RequiredPrivilege $provider.RequiredPrivilege `
                -Reason "Install the $($provider.Name) provider"

            if ($elevationStarted) {

                Write-Host ''
                Write-Host (
                    'Phoenix will continue in the elevated window.'
                ) -ForegroundColor Cyan

                # Stop this non-elevated installation pass.
                return
            }

            Write-Host '  ✗ Installation could not be elevated.' -ForegroundColor Red
            Write-Host ''

            continue
        }

        Write-Host '  Installing...' -ForegroundColor Yellow

        try {

            $null = $provider.InstallProvider()

            $provider.Available = $provider.TestAvailable()
        }
        catch {

            $provider.Available = $false

            Write-Warning (
                "Installation failed for {0}: {1}" -f
                $provider.Name,
                $_.Exception.Message
            )
        }

        if ($provider.Available) {

            Write-Host '  ✓ Installed successfully.' -ForegroundColor Green
        }
        else {

            Write-Host '  ✗ Failed to install.' -ForegroundColor Red
        }

        Write-Host ''
    }
}