function Install-MissingProviders {

    [CmdletBinding()]
    param(
        [Parameter()]
        [AllowNull()]
        [PhoenixContext]$Context
    )

    Write-Host '>>> Install-MissingProviders executed <<<' -ForegroundColor DarkGray
    Write-Host ''

    $context = $Context

    if ($null -eq $context) {
        $context = Get-PhoenixContext
    }

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

            [string]$availabilityWarning = (
                "Availability check failed for {0}: {1}" -f
                $provider.Name,
                $_.Exception.Message
            )

            $context.InitializationWarnings.Add(
                $availabilityWarning
            )

            Write-Warning $availabilityWarning
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

            [string]$elevationWarning = (
                'Installation could not be elevated for {0}.' -f
                $provider.Name
            )

            $context.InitializationWarnings.Add(
                $elevationWarning
            )

            Write-Host (
                "  ✗ $elevationWarning"
            ) -ForegroundColor Red
            Write-Host ''

            continue
        }

        Write-Host '  Installing...' -ForegroundColor Yellow

        try {

            $installResult = $provider.InstallProvider()

            $provider.Available = $provider.TestAvailable()
        }
        catch {

            $provider.Available = $false

            [string]$installationWarning = (
                "Installation failed for {0}: {1}" -f
                $provider.Name,
                $_.Exception.Message
            )

            $context.InitializationWarnings.Add(
                $installationWarning
            )

            Write-Warning $installationWarning
        }

        if ($provider.Available) {

            Write-Host '  ✓ Installed successfully.' -ForegroundColor Green
        }
        else {
            if (
                $null -ne $installResult -and
                [string]$installResult.Code -eq
                    'PHX_PROVIDER_INSTALL_APPROVAL_REQUIRED'
            ) {
                [string]$approvalMessage = if (
                    [string]::IsNullOrWhiteSpace(
                        [string]$installResult.Message
                    )
                ) {
                    'Manual installation approval is required.'
                }
                else {
                    [string]$installResult.Message
                }

                $context.InitializationWarnings.Add(
                    $approvalMessage
                )

                Write-Host (
                    "  ! Manual installation required: $approvalMessage"
                ) -ForegroundColor Yellow
            }
            else {
                Write-Host '  ✗ Failed to install.' -ForegroundColor Red
            }
        }

        Write-Host ''
    }
}
