##########################################################
## Method: InstallProvider
## Legacy source line: 79
##########################################################

[Result] InstallProvider() {

    [Result]$result = [Result]::Failure(
        'Chocolatey installation did not complete.'
    )

    [string]$installerPath = ''

    try {

        if ($this.TestAvailable()) {

            $this.Available = $true

            $result = [Result]::Success(
                'Chocolatey is already installed.'
            )
        }
        else {

            $context = Get-PhoenixContext

            if ($null -eq $context) {

                $result = [Result]::Failure(
                    'Phoenix context is unavailable.'
                )
            }
            elseif (-not $context.IsAdministrator) {

                $result = [Result]::Failure(
                    'Chocolatey installation requires administrator privileges.'
                )
            }
            else {

                [string]$installRoot = $env:ChocolateyInstall

                if ([string]::IsNullOrWhiteSpace($installRoot)) {

                    $installRoot = Join-Path `
                        $env:ProgramData `
                        'chocolatey'
                }

                [string]$chocoExecutable = Join-Path `
                    $installRoot `
                    'bin\choco.exe'

                [int]$processId = (
                    [System.Diagnostics.Process]::GetCurrentProcess().Id
                )

                $installerPath = Join-Path `
                    $env:TEMP `
                    "Phoenix-Chocolatey-Install-$processId.ps1"

                if (
                    (Test-Path -LiteralPath $installRoot) -and
                    (-not (Test-Path -LiteralPath $chocoExecutable))
                ) {

                    [string]$timestamp = Get-Date `
                        -Format 'yyyyMMdd-HHmmss'

                    [string]$parentPath = Split-Path `
                        $installRoot `
                        -Parent

                    [string]$backupPath = Join-Path `
                        $parentPath `
                        "chocolatey.incomplete-$timestamp"

                    Write-Host `
                        'Backing up incomplete Chocolatey installation:' `
                        -ForegroundColor Yellow

                    Write-Host "  From: $installRoot"
                    Write-Host "  To:   $backupPath"

                    Move-Item `
                        -LiteralPath $installRoot `
                        -Destination $backupPath `
                        -ErrorAction Stop
                }

                Write-Host `
                    'Downloading the Chocolatey installer...' `
                    -ForegroundColor Cyan

                [Net.ServicePointManager]::SecurityProtocol = (
                    [Net.ServicePointManager]::SecurityProtocol -bor
                    [Net.SecurityProtocolType]::Tls12
                )

                $null = Invoke-WebRequest `
                    -Uri 'https://community.chocolatey.org/install.ps1' `
                    -OutFile $installerPath `
                    -ProgressAction SilentlyContinue `
                    -ErrorAction Stop

                if (-not (Test-Path -LiteralPath $installerPath)) {

                    $result = [Result]::Failure(
                        'The Chocolatey installer was not downloaded.'
                    )
                }
                else {

                    Write-Host `
                        'Installing Chocolatey...' `
                        -ForegroundColor Cyan

                    # Display installer output without returning it
                    # from this typed class method.
                    & $installerPath | Out-Host

                    [string]$machineInstallRoot = (
                        [Environment]::GetEnvironmentVariable(
                            'ChocolateyInstall',
                            'Machine'
                        )
                    )

                    if (
                        -not [string]::IsNullOrWhiteSpace(
                            $machineInstallRoot
                        )
                    ) {

                        $installRoot = $machineInstallRoot
                        $env:ChocolateyInstall = $machineInstallRoot
                    }

                    [string]$chocoBin = Join-Path `
                        $installRoot `
                        'bin'

                    $chocoExecutable = Join-Path `
                        $chocoBin `
                        'choco.exe'

                    if (
                        (Test-Path -LiteralPath $chocoBin) -and
                        (($env:Path -split ';') -notcontains $chocoBin)
                    ) {

                        $env:Path = "$chocoBin;$env:Path"
                    }

                    $this.Available = $this.TestAvailable()

                    if ($this.Available) {

                        Write-Host `
                            'Chocolatey installed successfully.' `
                            -ForegroundColor Green

                        $result = [Result]::Success(
                            'Chocolatey installed successfully.'
                        )
                    }
                    else {

                        $result = [Result]::Failure(
                            "Chocolatey installation completed, but choco.exe was not found at '$chocoExecutable'."
                        )
                    }
                }
            }
        }
    }
    catch {

        $this.Available = $false

        $result = [Result]::Failure(
            "Chocolatey installation failed: $($_.Exception.Message)"
        )
    }
    finally {

        if (
            (-not [string]::IsNullOrWhiteSpace($installerPath)) -and
            (Test-Path -LiteralPath $installerPath)
        ) {

            Remove-Item `
                -LiteralPath $installerPath `
                -Force `
                -ErrorAction SilentlyContinue
        }
    }

    return $result
}

