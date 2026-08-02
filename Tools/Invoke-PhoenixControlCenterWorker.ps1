[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$ProjectRoot,

    [Parameter(Mandatory)]
    [ValidateScript({
        Test-Path -LiteralPath $_ -PathType Leaf
    })]
    [string]$RequestPath,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$ProgressPath,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$ResultPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-PhoenixWorkerJson {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [AllowNull()]
        [object]$InputObject
    )

    [string]$temporaryPath = (
        '{0}.{1}.tmp' -f
        $Path,
        [guid]::NewGuid().ToString('N')
    )

    try {
        $InputObject |
            ConvertTo-Json `
                -Depth 40 |
            Set-Content `
                -LiteralPath $temporaryPath `
                -Encoding UTF8 `
                -ErrorAction Stop

        Move-Item `
            -LiteralPath $temporaryPath `
            -Destination $Path `
            -Force `
            -ErrorAction Stop
    }
    finally {
        if (Test-Path -LiteralPath $temporaryPath) {
            Remove-Item `
                -LiteralPath $temporaryPath `
                -Force `
                -ErrorAction SilentlyContinue
        }
    }
}

function Write-PhoenixWorkerProgress {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateRange(0, 100)]
        [int]$Percent,

        [Parameter(Mandatory)]
        [string]$Message
    )

    Write-PhoenixWorkerJson `
        -Path $ProgressPath `
        -InputObject ([pscustomobject]@{
            UpdatedAtUtc = (Get-Date).ToUniversalTime()
            Percent      = $Percent
            Message      = $Message
        })
}

try {
    $request =
        Get-Content `
            -LiteralPath $RequestPath `
            -Raw `
            -ErrorAction Stop |
            ConvertFrom-Json `
                -ErrorAction Stop

    [string]$modulePath =
        Join-Path `
            $ProjectRoot `
            'Phoenix.psd1'

    Write-PhoenixWorkerProgress `
        -Percent 2 `
        -Message 'Loading Phoenix...'

    Import-Module `
        -Name $modulePath `
        -Force `
        -ErrorAction Stop `
        6>$null

    $null =
        Start-Phoenix `
            -ErrorAction Stop

    $phoenixModule =
        Get-Module `
            -Name Phoenix `
            -ErrorAction Stop

    $data = switch ([string]$request.Action) {
        'Inventory' {
            Write-PhoenixWorkerProgress `
                -Percent 20 `
                -Message 'Collecting system inventory...'

            $inventory = & $phoenixModule {
                Get-PhoenixControlCenterInventory
            }

            $inventory.Context = $null
            $inventory.Hardware = $null
            $inventory.Network = $null
            $inventory.OperatingSystem = $null

            foreach (
                $application in @(
                    $inventory.Applications
                )
            ) {
                $application.OriginalPackage = $null
            }

            $inventory
        }

        'Backup' {
            Write-PhoenixWorkerProgress `
                -Percent 10 `
                -Message 'Collecting data for the Phoenix restore manifest...'

            & $phoenixModule {
                param($workerParameters)

                Backup-Phoenix `
                    -OutputPath ([string]$workerParameters.OutputPath) `
                    -SkipDrivers:([bool]$workerParameters.SkipDrivers) `
                    -SkipPackages:([bool]$workerParameters.SkipPackages) `
                    -Confirm:$false
            } $request.Parameters
        }

        'ApplicationUpdates' {
            Write-PhoenixWorkerProgress `
                -Percent 35 `
                -Message 'Checking WinGet and Chocolatey for updates...'

            & $phoenixModule {
                Get-PhoenixControlCenterApplicationUpdate
            }
        }

        'PackageRelease' {
            Write-PhoenixWorkerProgress `
                -Percent 40 `
                -Message (
                    "Loading publisher metadata for '$($request.Parameters.Id)'..."
                )

            & $phoenixModule {
                param($workerParameters)

                Get-PhoenixControlCenterPackageRelease `
                    -Id $workerParameters.Id `
                    -Provider $workerParameters.Provider `
                    -Version $workerParameters.Version
            } $request.Parameters
        }

        'SearchPackages' {
            Write-PhoenixWorkerProgress `
                -Percent 25 `
                -Message (
                    "Searching for '$($request.Parameters.Query)'..."
                )

            & $phoenixModule {
                param($workerParameters)

                $searchParameters = @{
                    Query = $workerParameters.Query
                }
                if (
                    $null -ne $workerParameters.PSObject.Properties['Provider'] -and
                    @($workerParameters.Provider).Count -gt 0
                ) {
                    $searchParameters.Provider = @($workerParameters.Provider)
                }
                Search-PhoenixControlCenterPackage @searchParameters
            } $request.Parameters
        }

        'PackageAction' {
            $packages = @($request.Parameters.Packages)
            $allResults =
                [System.Collections.Generic.List[object]]::new()

            for (
                [int]$index = 0;
                $index -lt $packages.Count;
                $index++
            ) {
                $package = $packages[$index]
                [int]$percent = [Math]::Min(
                    95,
                    10 + [Math]::Floor(
                        (($index + 1) / $packages.Count) * 80
                    )
                )

                Write-PhoenixWorkerProgress `
                    -Percent $percent `
                    -Message (
                        "{0} {1} of {2}: {3}" -f
                        $request.Parameters.PackageAction,
                        ($index + 1),
                        $packages.Count,
                        $package.Name
                    )

                $results = @(
                    & $phoenixModule {
                        param(
                            $workerAction,
                            $workerPackage
                        )

                        Invoke-PhoenixControlCenterPackageAction `
                            -Action $workerAction `
                            -Package @($workerPackage) `
                            -AllowMigration:(
                                $workerAction -eq 'Update'
                            ) `
                            -Confirm:$false
                    } `
                        $request.Parameters.PackageAction `
                        $package
                )

                foreach ($result in $results) {
                    $allResults.Add($result)
                }
            }

            $allResults.ToArray()
        }

        'DriverAction' {
            Write-PhoenixWorkerProgress `
                -Percent 25 `
                -Message (
                    "Running driver action '$($request.Parameters.DriverAction)'..."
                )

            & $phoenixModule {
                param($workerParameters)

                Invoke-PhoenixControlCenterDriverAction `
                    -Action $workerParameters.DriverAction `
                    -UpdateId @($workerParameters.UpdateId) `
                    -InfName @($workerParameters.InfName) `
                    -Confirm:$false
            } $request.Parameters
        }

        'OemDriverAction' {
            Write-PhoenixWorkerProgress `
                -Percent 10 `
                -Message 'Preparing OEM driver operation...'

            & $phoenixModule {
                param($workerParameters)

                Invoke-PhoenixOemDriverAction `
                    -Action $workerParameters.OemAction `
                    -AdapterName $workerParameters.AdapterName `
                    -UpdateId $workerParameters.UpdateId `
                    -ApproveUtility:$workerParameters.ApproveUtility
            } $request.Parameters
        }

        'RestoreAction' {
            Write-PhoenixWorkerProgress `
                -Percent 10 `
                -Message 'Preparing the Phoenix restore job...'

            & $phoenixModule {
                param($workerParameters)

                $restoreParameters = @{
                    ManifestPath =
                        [string]$workerParameters.ManifestPath
                    SkipDrivers =
                        [bool]$workerParameters.SkipDrivers
                    SkipPackages =
                        [bool]$workerParameters.SkipPackages
                    Provider =
                        @($workerParameters.Provider)
                    ReinstallInstalled =
                        [bool]$workerParameters.ReinstallInstalled
                    StopOnError =
                        [bool]$workerParameters.StopOnError
                    Unattended =
                        [bool]$workerParameters.Unattended
                    Confirm = $false
                }

                Restore-Phoenix `
                    @restoreParameters
            } $request.Parameters
        }

        'RestorePlan' {
            Write-PhoenixWorkerProgress `
                -Percent 10 `
                -Message 'Building the Phoenix restore plan...'

            New-PhoenixRestorePlan `
                -ManifestPath ([string]$request.Parameters.ManifestPath) `
                -Provider @($request.Parameters.Provider) `
                -SkipDrivers:([bool]$request.Parameters.SkipDrivers) `
                -SkipPackages:([bool]$request.Parameters.SkipPackages) `
                -ReinstallInstalled:([bool]$request.Parameters.ReinstallInstalled)
        }

        'RestorePlanExecute' {
            Write-PhoenixWorkerProgress `
                -Percent 5 `
                -Message 'Starting checkpointed restore execution...'

            if (-not [string]::IsNullOrWhiteSpace(
                [string]$request.Parameters.SessionId
            )) {
                Resume-PhoenixRestore `
                    -SessionId ([string]$request.Parameters.SessionId) `
                    -CheckpointRoot ([string]$request.Parameters.CheckpointRoot) `
                    -RetryFailed:([bool]$request.Parameters.RetryFailed) `
                    -StopOnError:([bool]$request.Parameters.StopOnError) `
                    -Unattended `
                    -Confirm:$false
            }
            else {
                Invoke-PhoenixRestorePlan `
                    -Plan $request.Parameters.Plan `
                    -CheckpointRoot ([string]$request.Parameters.CheckpointRoot) `
                    -StopOnError:([bool]$request.Parameters.StopOnError) `
                    -Unattended `
                    -Confirm:$false
            }
        }

        'RestoreVerify' {
            Write-PhoenixWorkerProgress `
                -Percent 10 `
                -Message 'Rescanning applications and drivers for verification...'

            $verification = Test-PhoenixRestoreVerification `
                -SessionId ([string]$request.Parameters.SessionId) `
                -CheckpointRoot ([string]$request.Parameters.CheckpointRoot)
            $checkpoint = Get-PhoenixRestoreCheckpoint `
                -SessionId ([string]$request.Parameters.SessionId) `
                -CheckpointRoot ([string]$request.Parameters.CheckpointRoot)
            $checkpoint.VerificationSnapshot = $verification
            $null = Save-PhoenixRestoreCheckpoint `
                -Checkpoint $checkpoint `
                -CheckpointRoot ([string]$request.Parameters.CheckpointRoot) `
                -Confirm:$false
            $verification
        }

        default {
            throw (
                "Unsupported Control Center worker action '$($request.Action)'."
            )
        }
    }

    Write-PhoenixWorkerProgress `
        -Percent 100 `
        -Message 'Operation completed.'

    Write-PhoenixWorkerJson `
        -Path $ResultPath `
        -InputObject ([pscustomobject]@{
            Success        = $true
            CompletedAtUtc = (Get-Date).ToUniversalTime()
            Data           = $data
            Error          = ''
        })
}
catch {
    Write-PhoenixWorkerJson `
        -Path $ResultPath `
        -InputObject ([pscustomobject]@{
            Success        = $false
            CompletedAtUtc = (Get-Date).ToUniversalTime()
            Data           = $null
            Error          = $_.Exception.Message
        })

    exit 1
}
