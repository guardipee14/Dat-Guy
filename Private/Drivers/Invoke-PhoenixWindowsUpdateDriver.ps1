function ConvertFrom-PhoenixWuaResultCode {

    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [int]$ResultCode
    )

    switch ($ResultCode) {
        0 { return 'NotStarted' }
        1 { return 'InProgress' }
        2 { return 'Succeeded' }
        3 { return 'SucceededWithErrors' }
        4 { return 'Failed' }
        5 { return 'Aborted' }
        default { return "Unknown($ResultCode)" }
    }
}

function ConvertTo-PhoenixHResultHex {

    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [int]$HResult
    )

    [byte[]]$bytes = [BitConverter]::GetBytes(
        [int32]$HResult
    )

    [uint32]$unsignedValue =
        [BitConverter]::ToUInt32(
            $bytes,
            0
        )

    return ('0x{0:X8}' -f $unsignedValue)
}

function Invoke-PhoenixWindowsUpdateDriver {

    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter()]
        [switch]$ScanOnly,

        [Parameter()]
        [switch]$Unattended,

        [Parameter()]
        [string[]]$UpdateId = @(),

        [Parameter()]
        [ValidateRange(1, 1000)]
        [int]$ProgressId = 2,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$ProgressActivity = 'Phoenix driver stage'
    )

    $details =
        [System.Collections.Generic.List[object]]::new()

    $warnings =
        [System.Collections.Generic.List[string]]::new()

    $errors =
        [System.Collections.Generic.List[string]]::new()

    $selectedUpdates =
        [System.Collections.Generic.List[object]]::new()

    $selectedDetails =
        [System.Collections.Generic.List[object]]::new()

    $downloadUpdates =
        [System.Collections.Generic.List[object]]::new()

    $downloadDetails =
        [System.Collections.Generic.List[object]]::new()

    $installUpdates =
        [System.Collections.Generic.List[object]]::new()

    $installDetails =
        [System.Collections.Generic.List[object]]::new()

    [int]$searchResultCode = 0
    [int]$downloadResultCode = 0
    [int]$availableCount = 0
    [int]$selectedCount = 0
    [int]$cachedCount = 0
    [int]$downloadedCount = 0
    [int]$installedCount = 0
    [int]$partialCount = 0
    [int]$skippedCount = 0
    [int]$failedCount = 0
    [bool]$rebootRequired = $false
    [bool]$operationSucceeded = $false

    try {

        Write-PhoenixLog `
            -Level Info `
            -Message 'Searching Windows Update for applicable driver updates.'

        Write-Progress `
            -Id $ProgressId `
            -Activity $ProgressActivity `
            -Status '25% complete - Searching Windows Update for drivers...' `
            -CurrentOperation 'Windows Update Agent search' `
            -PercentComplete 25

        Write-Host (
            '[ 25%] Searching Windows Update for applicable drivers...'
        ) -ForegroundColor Cyan

        $session = New-Object `
            -ComObject 'Microsoft.Update.Session'

        $session.ClientApplicationID =
            'PhoenixDeploy'

        $searcher = $session.CreateUpdateSearcher()
        $searcher.Online = $true

        [string]$criteria =
            "IsInstalled=0 and Type='Driver' and IsHidden=0"

        $searchResult = $searcher.Search(
            $criteria
        )

        $searchResultCode =
            [int]$searchResult.ResultCode

        [string]$searchResultName =
            ConvertFrom-PhoenixWuaResultCode `
                -ResultCode $searchResultCode

        if ($searchResultCode -in @(4, 5)) {
            throw (
                'Windows Update driver search returned {0}.' -f
                $searchResultName
            )
        }

        if ($searchResultCode -eq 3) {
            $warnings.Add(
                'Windows Update completed the driver search with errors; results may be incomplete.'
            )
        }

        try {
            for (
                [int]$warningIndex = 0;
                $warningIndex -lt $searchResult.Warnings.Count;
                $warningIndex++
            ) {
                $warnings.Add(
                    [string]$searchResult.Warnings.Item(
                        $warningIndex
                    ).Message
                )
            }
        }
        catch {
            # Some Windows Update Agent versions do not expose warning text.
        }

        $availableCount =
            [int]$searchResult.Updates.Count

        Write-Progress `
            -Id $ProgressId `
            -Activity $ProgressActivity `
            -Status (
                '40% complete - Found {0} driver update(s).' -f
                $availableCount
            ) `
            -CurrentOperation 'Evaluating applicable driver updates' `
            -PercentComplete 40

        Write-Host (
            '[ 40%] Windows Update found {0} driver update(s).' -f
            $availableCount
        ) -ForegroundColor Cyan

        for (
            [int]$index = 0;
            $index -lt $availableCount;
            $index++
        ) {

            $update =
                $searchResult.Updates.Item(
                    $index
                )

            [string]$updateId = ''
            [int]$revisionNumber = 0
            [string]$driverClass = ''
            [string]$driverManufacturer = ''
            [string]$driverModel = ''
            [string]$driverVersion = ''
            [string]$driverVersionDate = ''
            [bool]$requiresUserInput = $false
            [bool]$canRequireSource = $false
            [string]$description = ''
            [string]$releaseNotes = ''
            [string]$supportUrl = ''
            [string[]]$moreInfoUrls = @()
            [string[]]$kbArticleIds = @()
            [string]$publishedAtUtc = ''
            [long]$minimumDownloadSize = 0
            [long]$maximumDownloadSize = 0

            try {
                $updateId =
                    [string]$update.Identity.UpdateID

                $revisionNumber =
                    [int]$update.Identity.RevisionNumber
            }
            catch {
                # Identity metadata is optional for reporting.
            }

            try {
                $driverClass =
                    [string]$update.DriverClass
            }
            catch {
                # Driver-specific metadata may be unavailable.
            }

            try {
                $driverManufacturer =
                    [string]$update.DriverManufacturer
            }
            catch {
                # Driver-specific metadata may be unavailable.
            }

            try {
                $driverModel =
                    [string]$update.DriverModel
            }
            catch {
                # Driver-specific metadata may be unavailable.
            }

            try {
                $driverVersion =
                    [string]$update.DriverVersion
            }
            catch {
                $driverVersion = ''
            }

            try {
                $driverVersionDate = (
                    [datetime]$update.DriverVerDate
                ).ToUniversalTime().ToString('o')
            }
            catch {
                $driverVersionDate = ''
            }

            try {
                $requiresUserInput =
                    [bool]$update.InstallationBehavior.CanRequestUserInput
            }
            catch {
                $requiresUserInput = $false
            }

            try {
                $canRequireSource =
                    [bool]$update.CanRequireSource
            }
            catch {
                $canRequireSource = $false
            }

            try {
                $description =
                    [string]$update.Description
            }
            catch {
                $description = ''
            }

            try {
                $releaseNotes =
                    [string]$update.ReleaseNotes
            }
            catch {
                $releaseNotes = ''
            }

            try {
                $supportUrl =
                    [string]$update.SupportUrl
            }
            catch {
                $supportUrl = ''
            }

            try {
                $moreInfoUrls = @(
                    for (
                        [int]$urlIndex = 0;
                        $urlIndex -lt $update.MoreInfoUrls.Count;
                        $urlIndex++
                    ) {
                        [string]$update.MoreInfoUrls.Item(
                            $urlIndex
                        )
                    }
                )
            }
            catch {
                $moreInfoUrls = @()
            }

            try {
                $kbArticleIds = @(
                    for (
                        [int]$kbIndex = 0;
                        $kbIndex -lt $update.KBArticleIDs.Count;
                        $kbIndex++
                    ) {
                        [string]$update.KBArticleIDs.Item(
                            $kbIndex
                        )
                    }
                )
            }
            catch {
                $kbArticleIds = @()
            }

            try {
                $publishedAtUtc = (
                    [datetime]$update.LastDeploymentChangeTime
                ).ToUniversalTime().ToString('o')
            }
            catch {
                $publishedAtUtc = ''
            }

            try {
                $minimumDownloadSize =
                    [long]$update.MinDownloadSize
            }
            catch {
                $minimumDownloadSize = 0
            }

            try {
                $maximumDownloadSize =
                    [long]$update.MaxDownloadSize
            }
            catch {
                $maximumDownloadSize = 0
            }

            $detail = [pscustomobject]@{
                Title               = [string]$update.Title
                UpdateId            = $updateId
                RevisionNumber      = $revisionNumber
                DriverClass         = $driverClass
                DriverManufacturer  = $driverManufacturer
                DriverModel         = $driverModel
                DriverVersion       = $driverVersion
                DriverVersionDate   = $driverVersionDate
                WasCached           = [bool]$update.IsDownloaded
                RequiresUserInput   = $requiresUserInput
                CanRequireSource    = $canRequireSource
                Description         = $description
                ReleaseNotes        = $releaseNotes
                SupportUrl          = $supportUrl
                MoreInfoUrls        = @($moreInfoUrls)
                KBArticleIds        = @($kbArticleIds)
                PublishedAtUtc      = $publishedAtUtc
                MinimumDownloadSize = $minimumDownloadSize
                MaximumDownloadSize = $maximumDownloadSize
                MetadataStatus      = if (
                    -not [string]::IsNullOrWhiteSpace(
                        $releaseNotes
                    ) -or
                    -not [string]::IsNullOrWhiteSpace(
                        $description
                    ) -or
                    -not [string]::IsNullOrWhiteSpace(
                        $supportUrl
                    ) -or
                    $moreInfoUrls.Count -gt 0
                ) {
                    'Publisher metadata available'
                }
                else {
                    'Not provided by publisher'
                }
                Status              = 'Available'
                DownloadResultCode  = $null
                DownloadResult      = $null
                DownloadHResult     = $null
                InstallResultCode   = $null
                InstallResult       = $null
                InstallHResult      = $null
                RebootRequired      = $false
            }

            $details.Add($detail)

            Write-Host (
                '         Available: {0}' -f
                $detail.Title
            ) -ForegroundColor DarkCyan

            if ($ScanOnly) {
                $selectedUpdates.Add($update)
                $selectedDetails.Add($detail)
                continue
            }

            if (
                $UpdateId.Count -gt 0 -and
                $updateId -notin $UpdateId
            ) {
                $detail.Status = 'NotSelected'
                continue
            }

            if (
                $Unattended -and
                (
                    $requiresUserInput -or
                    $canRequireSource
                )
            ) {

                $detail.Status =
                    'SkippedInteractiveRequirement'

                $skippedCount++

                $warnings.Add(
                    "Skipped driver update in unattended mode: $($detail.Title)"
                )

                continue
            }

            try {
                if (-not [bool]$update.EulaAccepted) {
                    $update.AcceptEula()
                }
            }
            catch {

                $detail.Status =
                    'EulaAcceptanceFailed'

                $failedCount++

                $errors.Add(
                    "Could not accept the update license for '$($detail.Title)': $($_.Exception.Message)"
                )

                continue
            }

            $selectedUpdates.Add($update)
            $selectedDetails.Add($detail)
        }

        $selectedCount =
            $selectedUpdates.Count

        if ($ScanOnly -or $selectedCount -eq 0) {

            $operationSucceeded =
                ($failedCount -eq 0)

            return [pscustomobject]@{
                OperationSucceeded = $operationSucceeded
                ScanOnly           = [bool]$ScanOnly
                SearchResultCode   = $searchResultCode
                DownloadResultCode = $downloadResultCode
                AvailableCount     = $availableCount
                SelectedCount      = $selectedCount
                CachedCount        = $cachedCount
                DownloadedCount    = $downloadedCount
                InstalledCount     = $installedCount
                PartialCount       = $partialCount
                SkippedCount       = $skippedCount
                FailedCount        = $failedCount
                RebootRequired     = $rebootRequired
                Updates            = @($details)
                Warnings           = @($warnings)
                Errors             = @($errors)
            }
        }

        for (
            [int]$index = 0;
            $index -lt $selectedUpdates.Count;
            $index++
        ) {

            $update = $selectedUpdates[$index]
            $detail = $selectedDetails[$index]

            if ([bool]$update.IsDownloaded) {

                $cachedCount++
                $detail.Status = 'Downloaded'
                $installUpdates.Add($update)
                $installDetails.Add($detail)
            }
            else {
                $downloadUpdates.Add($update)
                $downloadDetails.Add($detail)
            }
        }

        if ($downloadUpdates.Count -gt 0) {

            Write-Progress `
                -Id $ProgressId `
                -Activity $ProgressActivity `
                -Status (
                    '50% complete - Downloading {0} driver update(s)...' -f
                    $downloadUpdates.Count
                ) `
                -CurrentOperation 'Windows Update Agent download' `
                -PercentComplete 50

            Write-Host (
                '[ 50%] Downloading {0} driver update(s)...' -f
                $downloadUpdates.Count
            ) -ForegroundColor Cyan

            $downloadCollection = New-Object `
                -ComObject 'Microsoft.Update.UpdateColl'

            foreach ($update in $downloadUpdates) {
                [void]$downloadCollection.Add(
                    $update
                )
            }

            $downloader =
                $session.CreateUpdateDownloader()

            $downloader.ClientApplicationID =
                'PhoenixDeploy'

            $downloader.Updates =
                $downloadCollection

            $downloadResult =
                $downloader.Download()

            $downloadResultCode =
                [int]$downloadResult.ResultCode

            for (
                [int]$index = 0;
                $index -lt $downloadUpdates.Count;
                $index++
            ) {

                $update = $downloadUpdates[$index]
                $detail = $downloadDetails[$index]
                $updateDownloadResult =
                    $downloadResult.GetUpdateResult(
                        $index
                    )

                [int]$itemResultCode =
                    [int]$updateDownloadResult.ResultCode

                [int]$itemHResult =
                    [int]$updateDownloadResult.HResult

                $detail.DownloadResultCode =
                    $itemResultCode

                $detail.DownloadResult =
                    ConvertFrom-PhoenixWuaResultCode `
                        -ResultCode $itemResultCode

                $detail.DownloadHResult =
                    ConvertTo-PhoenixHResultHex `
                        -HResult $itemHResult

                if (
                    [bool]$update.IsDownloaded -and
                    $itemResultCode -in @(2, 3)
                ) {

                    $downloadedCount++
                    $detail.Status = 'Downloaded'
                    $installUpdates.Add($update)
                    $installDetails.Add($detail)

                    if ($itemResultCode -eq 3) {
                        $warnings.Add(
                            "Driver update downloaded with warnings: $($detail.Title)"
                        )
                    }
                }
                else {

                    $failedCount++
                    $detail.Status = 'DownloadFailed'

                    $errors.Add(
                        "Driver update download failed: $($detail.Title) [$($detail.DownloadHResult)]"
                    )
                }
            }
        }

        [int]$installCount =
            $installUpdates.Count

        for (
            [int]$index = 0;
            $index -lt $installCount;
            $index++
        ) {

            $update = $installUpdates[$index]
            $detail = $installDetails[$index]

            [int]$installPercent =
                65 + [Math]::Floor(
                    (
                        $index /
                        [Math]::Max(1, $installCount)
                    ) * 20
                )

            Write-Progress `
                -Id $ProgressId `
                -Activity $ProgressActivity `
                -Status (
                    '{0}% complete - Installing driver {1} of {2}...' -f
                    $installPercent,
                    ($index + 1),
                    $installCount
                ) `
                -CurrentOperation $detail.Title `
                -PercentComplete $installPercent

            Write-Host (
                '[{0,3}%] [{1}/{2}] Installing {3}...' -f
                $installPercent,
                ($index + 1),
                $installCount,
                $detail.Title
            ) -ForegroundColor Cyan

            $singleUpdateCollection = New-Object `
                -ComObject 'Microsoft.Update.UpdateColl'

            [void]$singleUpdateCollection.Add(
                $update
            )

            $installer =
                $session.CreateUpdateInstaller()

            $installer.ClientApplicationID =
                'PhoenixDeploy'

            $installer.AllowSourcePrompts =
                -not [bool]$Unattended

            $installer.Updates =
                $singleUpdateCollection

            try {

                $installationResult =
                    $installer.Install()

                $updateInstallResult =
                    $installationResult.GetUpdateResult(
                        0
                    )

                [int]$itemResultCode =
                    [int]$updateInstallResult.ResultCode

                [int]$itemHResult =
                    [int]$updateInstallResult.HResult

                [bool]$itemRebootRequired =
                    [bool]$updateInstallResult.RebootRequired -or
                    [bool]$installationResult.RebootRequired

                $detail.InstallResultCode =
                    $itemResultCode

                $detail.InstallResult =
                    ConvertFrom-PhoenixWuaResultCode `
                        -ResultCode $itemResultCode

                $detail.InstallHResult =
                    ConvertTo-PhoenixHResultHex `
                        -HResult $itemHResult

                $detail.RebootRequired =
                    $itemRebootRequired

                if ($itemRebootRequired) {
                    $rebootRequired = $true
                }

                switch ($itemResultCode) {

                    2 {
                        $installedCount++
                        $detail.Status = 'Installed'

                        Write-Host (
                            '         Installed: {0}' -f
                            $detail.Title
                        ) -ForegroundColor Green
                    }

                    3 {
                        $partialCount++
                        $detail.Status = 'InstalledWithErrors'

                        $warnings.Add(
                            "Driver update installed with errors: $($detail.Title) [$($detail.InstallHResult)]"
                        )

                        Write-Host (
                            '         Installed with errors: {0}' -f
                            $detail.Title
                        ) -ForegroundColor Yellow
                    }

                    default {
                        $failedCount++
                        $detail.Status = 'InstallFailed'

                        $errors.Add(
                            "Driver update installation failed: $($detail.Title) [$($detail.InstallHResult)]"
                        )

                        Write-Host (
                            '         Failed: {0} [{1}]' -f
                            $detail.Title,
                            $detail.InstallHResult
                        ) -ForegroundColor Red
                    }
                }
            }
            catch {

                $failedCount++
                $detail.Status = 'InstallException'

                $errors.Add(
                    "Driver update installation threw an exception for '$($detail.Title)': $($_.Exception.Message)"
                )

                Write-Host (
                    '         Failed: {0} - {1}' -f
                    $detail.Title,
                    $_.Exception.Message
                ) -ForegroundColor Red
            }
        }

        $operationSucceeded =
            ($failedCount -eq 0 -and $partialCount -eq 0)

        return [pscustomobject]@{
            OperationSucceeded = $operationSucceeded
            ScanOnly           = [bool]$ScanOnly
            SearchResultCode   = $searchResultCode
            DownloadResultCode = $downloadResultCode
            AvailableCount     = $availableCount
            SelectedCount      = $selectedCount
            CachedCount        = $cachedCount
            DownloadedCount    = $downloadedCount
            InstalledCount     = $installedCount
            PartialCount       = $partialCount
            SkippedCount       = $skippedCount
            FailedCount        = $failedCount
            RebootRequired     = $rebootRequired
            Updates            = @($details)
            Warnings           = @($warnings)
            Errors             = @($errors)
        }
    }
    catch {

        $errors.Add(
            $_.Exception.Message
        )

        Write-PhoenixLog `
            -Level Error `
            -Message (
                'Windows Update driver operation failed: {0}' -f
                $_.Exception.Message
            )

        return [pscustomobject]@{
            OperationSucceeded = $false
            ScanOnly           = [bool]$ScanOnly
            SearchResultCode   = $searchResultCode
            DownloadResultCode = $downloadResultCode
            AvailableCount     = $availableCount
            SelectedCount      = $selectedCount
            CachedCount        = $cachedCount
            DownloadedCount    = $downloadedCount
            InstalledCount     = $installedCount
            PartialCount       = $partialCount
            SkippedCount       = $skippedCount
            FailedCount        = [Math]::Max(1, $failedCount)
            RebootRequired     = $rebootRequired
            Updates            = @($details)
            Warnings           = @($warnings)
            Errors             = @($errors)
        }
    }
}
