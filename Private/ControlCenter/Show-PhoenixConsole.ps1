function Read-PhoenixControlCenterSelection {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$Items,

        [Parameter()]
        [string]$Prompt = (
            'Enter item numbers separated by commas, A for all, or B to go back'
        )
    )

    if ($Items.Count -eq 0) {
        return @()
    }

    [string]$response =
        Read-Host $Prompt

    if (
        [string]::IsNullOrWhiteSpace($response) -or
        $response.Trim() -ieq 'B'
    ) {
        return @()
    }

    if ($response.Trim() -ieq 'A') {
        return @($Items)
    }

    $selectedItems =
        [System.Collections.Generic.List[object]]::new()

    foreach (
        $token in @(
            $response -split ','
        )
    ) {

        [int]$number = 0

        if (
            [int]::TryParse(
                $token.Trim(),
                [ref]$number
            ) -and
            $number -ge 1 -and
            $number -le $Items.Count
        ) {
            $selectedItems.Add(
                $Items[$number - 1]
            )
        }
    }

    return $selectedItems.ToArray()
}

function Confirm-PhoenixControlCenterAction {

    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string]$Message
    )

    [string]$response =
        Read-Host "$Message [Y/N]"

    return $response.Trim() -ieq 'Y'
}

function Show-PhoenixControlCenterResults {

    [CmdletBinding()]
    param(
        [Parameter()]
        [object[]]$Result = @()
    )

    if ($Result.Count -eq 0) {
        Write-Host 'No results were returned.' `
            -ForegroundColor DarkYellow

        return
    }

    $Result |
        Select-Object `
            -Property @(
                'Success'
                'Code'
                'Message'
            ) |
        Format-Table -Wrap -AutoSize |
        Out-Host
}

function Show-PhoenixControlCenterOverview {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Inventory
    )

    Clear-Host

    Write-Host 'Phoenix Control Center' `
        -ForegroundColor Cyan

    Write-Host '======================' `
        -ForegroundColor DarkCyan

    Write-Host ''

    $Inventory.Summary |
        Format-List `
            -Property @(
                'ComputerName'
                'Manufacturer'
                'Model'
                'Processor'
                'MemoryGB'
                'OperatingSystem'
                'OsVersion'
                'OsBuild'
                'Architecture'
                'Administrator'
            ) |
        Out-Host

    [pscustomobject]@{
        Applications       = $Inventory.Applications.Count
        ActionableApps     = @(
            $Inventory.Applications |
                Where-Object Actionable
        ).Count
        InstalledDrivers   = $Inventory.Drivers.Count
        ProblemDrivers     = @(
            $Inventory.Drivers |
                Where-Object HasProblem
        ).Count
        AvailableProviders = @(
            $Inventory.Providers |
                Where-Object Available
        ).Count
    } |
        Format-List |
        Out-Host

    if ($Inventory.Warnings.Count -gt 0) {

        Write-Host 'Inventory warnings:' `
            -ForegroundColor Yellow

        $Inventory.Warnings |
            ForEach-Object {
                Write-Host "  - $_" `
                    -ForegroundColor Yellow
            }
    }
}

function Show-PhoenixIndexedItems {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$Items,

        [Parameter(Mandatory)]
        [string[]]$Property
    )

    $index = 0

    @(
        foreach ($item in $Items) {

            $index++

            $record = [ordered]@{
                Number = $index
            }

            foreach ($propertyName in $Property) {
                $record[$propertyName] =
                    $item.$propertyName
            }

            [pscustomobject]$record
        }
    ) |
        Format-Table -Wrap -AutoSize |
        Out-Host
}

function Show-PhoenixConsole {

    [CmdletBinding()]
    param()

    Write-Host ''
    Write-Host 'Collecting Phoenix inventory...' `
        -ForegroundColor Cyan

    $inventory =
        Get-PhoenixControlCenterInventory

    while ($true) {

        Show-PhoenixControlCenterOverview `
            -Inventory $inventory

        Write-Host '1.  Refresh all inventory'
        Write-Host '2.  View installed applications'
        Write-Host '3.  Search and install applications'
        Write-Host '4.  Update selected applications'
        Write-Host '5.  Update all actionable applications'
        Write-Host '6.  Repair selected applications'
        Write-Host '7.  Repair all actionable applications'
        Write-Host '8.  View installed drivers'
        Write-Host '9.  Scan and install selected driver updates'
        Write-Host '10. Update all applicable drivers'
        Write-Host '11. Repair selected installed drivers'
        Write-Host '12. Repair all problem drivers'
        Write-Host 'Q.  Exit'
        Write-Host ''

        [string]$choice =
            Read-Host 'Select an action'

        switch ($choice.Trim().ToUpperInvariant()) {
            '1' {
                Write-Host 'Refreshing inventory...' `
                    -ForegroundColor Cyan

                $inventory =
                    Get-PhoenixControlCenterInventory
            }

            '2' {
                Clear-Host

                Show-PhoenixIndexedItems `
                    -Items $inventory.Applications `
                    -Property @(
                        'Name'
                        'Id'
                        'Version'
                        'Provider'
                        'Actionable'
                    )

                Read-Host 'Press Enter to continue'
            }

            '3' {
                Clear-Host

                [string]$query =
                    Read-Host 'Application name or search term'

                if (
                    [string]::IsNullOrWhiteSpace($query)
                ) {
                    continue
                }

                Write-Host "Searching for '$query'..." `
                    -ForegroundColor Cyan

                $searchResults = @(
                    Search-PhoenixControlCenterPackage `
                        -Query $query
                )

                Show-PhoenixIndexedItems `
                    -Items $searchResults `
                    -Property @(
                        'Name'
                        'Id'
                        'Version'
                        'Provider'
                    )

                $selected = @(
                    Read-PhoenixControlCenterSelection `
                        -Items $searchResults
                )

                if (
                    $selected.Count -gt 0 -and
                    (
                        Confirm-PhoenixControlCenterAction `
                            -Message (
                                "Install $($selected.Count) selected application(s)?"
                            )
                    )
                ) {

                    $results = @(
                        Invoke-PhoenixControlCenterPackageAction `
                            -Action Install `
                            -Package $selected `
                            -Confirm:$false
                    )

                    Show-PhoenixControlCenterResults `
                        -Result $results

                    $inventory =
                        Get-PhoenixControlCenterInventory

                    Read-Host 'Press Enter to continue'
                }
            }

            '4' {
                $actionable = @(
                    $inventory.Applications |
                        Where-Object Actionable
                )

                Show-PhoenixIndexedItems `
                    -Items $actionable `
                    -Property @(
                        'Name'
                        'Id'
                        'Version'
                        'Provider'
                    )

                $selected = @(
                    Read-PhoenixControlCenterSelection `
                        -Items $actionable
                )

                if (
                    $selected.Count -gt 0 -and
                    (
                        Confirm-PhoenixControlCenterAction `
                            -Message (
                                "Update $($selected.Count) selected application(s)?"
                            )
                    )
                ) {

                    $results = @(
                        Invoke-PhoenixControlCenterPackageAction `
                            -Action Update `
                            -Package $selected `
                            -AllowMigration `
                            -Confirm:$false
                    )

                    Show-PhoenixControlCenterResults `
                        -Result $results

                    Read-Host 'Press Enter to continue'
                }
            }

            '5' {
                $actionable = @(
                    $inventory.Applications |
                        Where-Object Actionable
                )

                if (
                    $actionable.Count -gt 0 -and
                    (
                        Confirm-PhoenixControlCenterAction `
                            -Message (
                                "Update all $($actionable.Count) actionable application(s)?"
                            )
                    )
                ) {

                    $results = @(
                        Invoke-PhoenixControlCenterPackageAction `
                            -Action Update `
                            -Package $actionable `
                            -AllowMigration `
                            -Confirm:$false
                    )

                    Show-PhoenixControlCenterResults `
                        -Result $results

                    Read-Host 'Press Enter to continue'
                }
            }

            '6' {
                $actionable = @(
                    $inventory.Applications |
                        Where-Object Actionable
                )

                Show-PhoenixIndexedItems `
                    -Items $actionable `
                    -Property @(
                        'Name'
                        'Id'
                        'Version'
                        'Provider'
                    )

                $selected = @(
                    Read-PhoenixControlCenterSelection `
                        -Items $actionable
                )

                if (
                    $selected.Count -gt 0 -and
                    (
                        Confirm-PhoenixControlCenterAction `
                            -Message (
                                "Repair $($selected.Count) selected application(s)?"
                            )
                    )
                ) {

                    $results = @(
                        Invoke-PhoenixControlCenterPackageAction `
                            -Action Repair `
                            -Package $selected `
                            -Confirm:$false
                    )

                    Show-PhoenixControlCenterResults `
                        -Result $results

                    Read-Host 'Press Enter to continue'
                }
            }

            '7' {
                $actionable = @(
                    $inventory.Applications |
                        Where-Object Actionable
                )

                if (
                    $actionable.Count -gt 0 -and
                    (
                        Confirm-PhoenixControlCenterAction `
                            -Message (
                                "Repair all $($actionable.Count) actionable application(s)?"
                            )
                    )
                ) {

                    $results = @(
                        Invoke-PhoenixControlCenterPackageAction `
                            -Action Repair `
                            -Package $actionable `
                            -Confirm:$false
                    )

                    Show-PhoenixControlCenterResults `
                        -Result $results

                    Read-Host 'Press Enter to continue'
                }
            }

            '8' {
                Clear-Host

                Show-PhoenixIndexedItems `
                    -Items $inventory.Drivers `
                    -Property @(
                        'Name'
                        'Manufacturer'
                        'Version'
                        'Class'
                        'InfName'
                        'ProblemCode'
                    )

                Read-Host 'Press Enter to continue'
            }

            '9' {
                Write-Host 'Scanning Windows Update for drivers...' `
                    -ForegroundColor Cyan

                $scanResults = @(
                    Invoke-PhoenixControlCenterDriverAction `
                        -Action ScanUpdates
                )

                $scanResult =
                    $scanResults |
                    Select-Object -Last 1

                $availableUpdates = @(
                    $scanResult.Data.Updates |
                        Where-Object {
                            -not [string]::IsNullOrWhiteSpace(
                                $_.UpdateId
                            )
                        }
                )

                Show-PhoenixIndexedItems `
                    -Items $availableUpdates `
                    -Property @(
                        'Title'
                        'DriverManufacturer'
                        'DriverModel'
                        'DriverClass'
                        'Status'
                    )

                $selected = @(
                    Read-PhoenixControlCenterSelection `
                        -Items $availableUpdates
                )

                if (
                    $selected.Count -gt 0 -and
                    (
                        Confirm-PhoenixControlCenterAction `
                            -Message (
                                "Install $($selected.Count) selected driver update(s)?"
                            )
                    )
                ) {

                    $results = @(
                        Invoke-PhoenixControlCenterDriverAction `
                            -Action InstallSelected `
                            -UpdateId @(
                                $selected.UpdateId
                            ) `
                            -Confirm:$false
                    )

                    Show-PhoenixControlCenterResults `
                        -Result $results

                    Read-Host 'Press Enter to continue'
                }
            }

            '10' {
                if (
                    Confirm-PhoenixControlCenterAction `
                        -Message (
                            'Install every applicable Windows Update driver?'
                        )
                ) {

                    $results = @(
                        Invoke-PhoenixControlCenterDriverAction `
                            -Action UpdateAll `
                            -Confirm:$false
                    )

                    Show-PhoenixControlCenterResults `
                        -Result $results

                    Read-Host 'Press Enter to continue'
                }
            }

            '11' {
                Show-PhoenixIndexedItems `
                    -Items $inventory.Drivers `
                    -Property @(
                        'Name'
                        'Manufacturer'
                        'Version'
                        'Class'
                        'InfName'
                        'ProblemCode'
                    )

                $selected = @(
                    Read-PhoenixControlCenterSelection `
                        -Items $inventory.Drivers
                )

                if (
                    $selected.Count -gt 0 -and
                    (
                        Confirm-PhoenixControlCenterAction `
                            -Message (
                                "Reinstall $($selected.Count) selected driver package(s)?"
                            )
                    )
                ) {

                    $results = @(
                        Invoke-PhoenixControlCenterDriverAction `
                            -Action RepairSelected `
                            -InfName @(
                                $selected.InfName
                            ) `
                            -Confirm:$false
                    )

                    Show-PhoenixControlCenterResults `
                        -Result $results

                    Read-Host 'Press Enter to continue'
                }
            }

            '12' {
                $problemDrivers = @(
                    $inventory.Drivers |
                        Where-Object HasProblem
                )

                if ($problemDrivers.Count -eq 0) {
                    Write-Host 'No problem drivers were found.' `
                        -ForegroundColor Green

                    Read-Host 'Press Enter to continue'
                    continue
                }

                if (
                    Confirm-PhoenixControlCenterAction `
                        -Message (
                            "Repair all $($problemDrivers.Count) problem driver(s)?"
                        )
                ) {

                    $results = @(
                        Invoke-PhoenixControlCenterDriverAction `
                            -Action RepairProblems `
                            -Confirm:$false
                    )

                    Show-PhoenixControlCenterResults `
                        -Result $results

                    Read-Host 'Press Enter to continue'
                }
            }

            'Q' {
                return
            }

            default {
                Write-Host 'Unknown selection.' `
                    -ForegroundColor Yellow

                Start-Sleep -Milliseconds 700
            }
        }
    }
}
