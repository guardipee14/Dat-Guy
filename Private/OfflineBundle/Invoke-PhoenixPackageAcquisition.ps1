function Get-PhoenixPackageAcquisitionValue {

    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter()]
        [AllowNull()]
        [object]$InputObject,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string[]]$Name
    )

    if ($null -eq $InputObject) {
        return ''
    }

    foreach ($candidateName in $Name) {
        if (
            [string]::IsNullOrWhiteSpace(
                $candidateName
            )
        ) {
            continue
        }

        [object]$candidateValue =
            $null

        if (
            $InputObject -is
                [System.Collections.IDictionary]
        ) {
            foreach ($key in $InputObject.Keys) {
                if (
                    [string]::Equals(
                        [string]$key,
                        $candidateName,
                        [StringComparison]::OrdinalIgnoreCase
                    )
                ) {
                    $candidateValue =
                        $InputObject[$key]

                    break
                }
            }
        }
        else {
            $property =
                $InputObject.PSObject.Properties[
                    $candidateName
                ]

            if ($null -ne $property) {
                $candidateValue =
                    $property.Value
            }
        }

        if ($null -eq $candidateValue) {
            continue
        }

        [string]$textValue =
            [string]$candidateValue

        if (
            -not [string]::IsNullOrWhiteSpace(
                $textValue
            )
        ) {
            return $textValue.Trim()
        }
    }

    return ''
}

function ConvertTo-PhoenixPackageAcquisitionSource {

    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter()]
        [AllowNull()]
        [string]$Value
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $null
    }

    [string]$candidate =
        $Value.Trim()

    try {
        if (
            [IO.Path]::IsPathFullyQualified(
                $candidate
            )
        ) {
            return [pscustomobject]@{
                Kind = 'Local'
                Value = [IO.Path]::GetFullPath($candidate)
            }
        }
    }
    catch {
    }

    [uri]$candidateUri =
        $null

    if (
        [uri]::TryCreate(
            $candidate,
            [UriKind]::Absolute,
            [ref]$candidateUri
        )
    ) {
        if ($candidateUri.IsFile) {
            return [pscustomobject]@{
                Kind = 'Local'
                Value = $candidateUri.LocalPath
            }
        }

        if (
            $candidateUri.Scheme -in
                @(
                    'https'
                    'http'
                )
        ) {
            return [pscustomobject]@{
                Kind = 'Uri'
                Value = $candidateUri.AbsoluteUri
            }
        }
    }

    return $null
}

function Get-PhoenixScoopCacheFile {

    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$PackageId,

        [Parameter()]
        [AllowEmptyString()]
        [string]$Version = ''
    )

    $roots =
        [System.Collections.Generic.List[string]]::new()

    foreach ($candidateRoot in @(
        $env:SCOOP
        $(
            if (
                -not [string]::IsNullOrWhiteSpace(
                    $env:USERPROFILE
                )
            ) {
                Join-Path $env:USERPROFILE 'scoop'
            }
        )
    )) {
        if (
            -not [string]::IsNullOrWhiteSpace(
                [string]$candidateRoot
            ) -and
            -not $roots.Contains(
                [string]$candidateRoot
            )
        ) {
            $roots.Add(
                [string]$candidateRoot
            )
        }
    }

    foreach ($root in $roots) {
        [string]$cacheRoot =
            Join-Path $root 'cache'

        if (
            -not (
                Test-Path `
                    -LiteralPath $cacheRoot `
                    -PathType Container
            )
        ) {
            continue
        }

        [string]$namePattern =
            '{0}#*' -f $PackageId

        if (
            -not [string]::IsNullOrWhiteSpace(
                $Version
            )
        ) {
            $namePattern =
                '{0}#{1}#*' -f
                $PackageId,
                $Version
        }

        $cacheFile =
            @(
                Get-ChildItem `
                    -LiteralPath $cacheRoot `
                    -File `
                    -Force `
                    -ErrorAction SilentlyContinue |
                    Where-Object {
                        $_.Name -like $namePattern
                    } |
                    Sort-Object LastWriteTimeUtc -Descending
            ) |
            Select-Object -First 1

        if ($null -ne $cacheFile) {
            return $cacheFile.FullName
        }
    }

    return ''
}

function Invoke-PhoenixScoopPackageDownload {

    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$PackageId,

        [Parameter()]
        [AllowEmptyString()]
        [string]$Version = ''
    )

    $scoopCommand =
        Get-Command `
            scoop `
            -ErrorAction SilentlyContinue

    if ($null -eq $scoopCommand) {
        return ''
    }

    [string]$target =
        $PackageId

    if (
        -not [string]::IsNullOrWhiteSpace(
            $Version
        )
    ) {
        $target =
            '{0}@{1}' -f
            $PackageId,
            $Version
    }

    $LASTEXITCODE = 0

    $null =
        & $scoopCommand.Source `
            download `
            $target `
            2>&1

    if ($LASTEXITCODE -ne 0) {
        throw (
            "Scoop could not download '$target'."
        )
    }

    return Get-PhoenixScoopCacheFile `
        -PackageId $PackageId `
        -Version $Version
}

function Resolve-PhoenixPackageAcquisitionSource {

    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [PhoenixPackageAcquisitionRequest]$Request,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Provider
    )

    foreach ($candidate in @(
        Get-PhoenixPackageAcquisitionValue `
            -InputObject $Request.Metadata `
            -Name @(
                'SourcePath'
                'LocalPath'
                'LiteralPath'
                'CachePath'
                'AssetPath'
            )
        Get-PhoenixPackageAcquisitionValue `
            -InputObject $Request.Metadata `
            -Name @(
                'DownloadUri'
                'SourceUri'
                'AssetUri'
                'Uri'
            )
        Get-PhoenixPackageAcquisitionValue `
            -InputObject $Request.Package `
            -Name @(
                'DownloadedFile'
                'DownloadUri'
                'AssetDownloadUri'
                'AssetUri'
                'SourceUri'
                'Uri'
            )
        Get-PhoenixPackageAcquisitionValue `
            -InputObject $Request.Package `
            -Name @(
                'Source'
            )
    )) {
        $resolvedCandidate =
            ConvertTo-PhoenixPackageAcquisitionSource `
                -Value $candidate

        if ($null -ne $resolvedCandidate) {
            return $resolvedCandidate
        }
    }

    if (
        [string]::Equals(
            $Provider,
            'PowerShell Gallery',
            [StringComparison]::OrdinalIgnoreCase
        ) -and
        -not [string]::IsNullOrWhiteSpace(
            $Request.Package.Id
        ) -and
        -not [string]::IsNullOrWhiteSpace(
            $Request.Package.Version
        )
    ) {
        [string]$escapedId =
            [uri]::EscapeDataString(
                $Request.Package.Id
            )

        [string]$escapedVersion =
            [uri]::EscapeDataString(
                $Request.Package.Version
            )

        return [pscustomobject]@{
            Kind = 'Uri'
            Value =
                (
                    'https://www.powershellgallery.com/' +
                    "api/v2/package/$escapedId/$escapedVersion"
                )
        }
    }

    if (
        [string]::Equals(
            $Provider,
            'Scoop',
            [StringComparison]::OrdinalIgnoreCase
        )
    ) {
        [string]$cachePath =
            Get-PhoenixScoopCacheFile `
                -PackageId $Request.Package.Id `
                -Version $Request.Package.Version

        if (
            $Request.ForceRefresh -or
            [string]::IsNullOrWhiteSpace(
                $cachePath
            )
        ) {
            $cachePath =
                Invoke-PhoenixScoopPackageDownload `
                    -PackageId $Request.Package.Id `
                    -Version $Request.Package.Version
        }

        if (
            -not [string]::IsNullOrWhiteSpace(
                $cachePath
            )
        ) {
            return [pscustomobject]@{
                Kind = 'Local'
                Value = $cachePath
            }
        }
    }

    return $null
}

function Get-PhoenixPackageAcquisitionFileName {

    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [PhoenixPackageAcquisitionRequest]$Request,

        [Parameter(Mandatory)]
        [pscustomobject]$Source,

        [Parameter()]
        [AllowEmptyString()]
        [string]$DefaultExtension = ''
    )

    [string]$fileName =
        Get-PhoenixPackageAcquisitionValue `
            -InputObject $Request.Metadata `
            -Name @(
                'FileName'
                'AssetName'
            )

    if (
        [string]::IsNullOrWhiteSpace(
            $fileName
        ) -and
        $Source.Kind -eq 'Local'
    ) {
        $fileName =
            Split-Path `
                -Path $Source.Value `
                -Leaf
    }

    if (
        [string]::IsNullOrWhiteSpace(
            $fileName
        ) -and
        $Source.Kind -eq 'Uri'
    ) {
        [uri]$sourceUri =
            [uri]$Source.Value

        [string]$uriLeaf =
            [uri]::UnescapeDataString(
                (
                    Split-Path `
                        -Path $sourceUri.AbsolutePath `
                        -Leaf
                )
            )

        [string]$uriExtension =
            [IO.Path]::GetExtension(
                $uriLeaf
            )

        if (
            -not [string]::IsNullOrWhiteSpace(
                $uriExtension
            ) -and
            (
                [string]::IsNullOrWhiteSpace(
                    $DefaultExtension
                ) -or
                [string]::Equals(
                    $uriExtension,
                    $DefaultExtension,
                    [StringComparison]::OrdinalIgnoreCase
                )
            )
        ) {
            $fileName =
                $uriLeaf
        }
    }

    if ([string]::IsNullOrWhiteSpace($fileName)) {
        [string]$identity =
            $Request.Package.Id

        if ([string]::IsNullOrWhiteSpace($identity)) {
            $identity =
                $Request.Package.Name
        }

        [string]$safeIdentity =
            [regex]::Replace(
                $identity,
                '[^A-Za-z0-9._-]',
                '_'
            )

        [string]$safeVersion =
            [regex]::Replace(
                $Request.Package.Version,
                '[^A-Za-z0-9._+-]',
                '_'
            )

        $fileName =
            $safeIdentity

        if (
            -not [string]::IsNullOrWhiteSpace(
                $safeVersion
            )
        ) {
            $fileName =
                '{0}-{1}' -f
                $fileName,
                $safeVersion
        }

        $fileName +=
            $DefaultExtension
    }

    $fileName =
        Split-Path `
            -Path $fileName `
            -Leaf

    if ([string]::IsNullOrWhiteSpace($fileName)) {
        throw 'A safe package-acquisition filename could not be created.'
    }

    return $fileName
}

function Get-PhoenixPackageAcquisitionMediaType {

    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$FileName
    )

    switch (
        [IO.Path]::GetExtension(
            $FileName
        ).ToLowerInvariant()
    ) {
        '.nupkg' {
            return 'application/zip'
        }
        '.zip' {
            return 'application/zip'
        }
        '.msi' {
            return 'application/x-msi'
        }
        '.msix' {
            return 'application/msix'
        }
        '.exe' {
            return 'application/vnd.microsoft.portable-executable'
        }
        default {
            return 'application/octet-stream'
        }
    }
}

function New-PhoenixPackageAcquisitionWorkingDirectory {

    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [PhoenixPackageAcquisitionRequest]$Request
    )

    [string]$workingRoot =
        $Request.WorkingDirectory

    if (
        [string]::IsNullOrWhiteSpace(
            $workingRoot
        )
    ) {
        $workingRoot =
            [IO.Path]::GetTempPath()
    }

    [string]$workingDirectory =
        Join-Path `
            $workingRoot `
            (
                'Phoenix-PackageAcquisition-{0}' -f
                $Request.RequestId.Replace('-', '')
            )

    $null =
        New-Item `
            -ItemType Directory `
            -Path $workingDirectory `
            -Force `
            -ErrorAction Stop

    return (
        Resolve-Path `
            -LiteralPath $workingDirectory `
            -ErrorAction Stop
    ).Path
}

function Test-PhoenixPackageAcquisitionExtension {

    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$FileName,

        [Parameter()]
        [AllowEmptyCollection()]
        [string[]]$AllowedExtension = @()
    )

    if (@($AllowedExtension).Count -eq 0) {
        return $true
    }

    [string]$extension =
        [IO.Path]::GetExtension(
            $FileName
        )

    foreach ($allowed in @($AllowedExtension)) {
        if (
            [string]::Equals(
                $extension,
                $allowed,
                [StringComparison]::OrdinalIgnoreCase
            )
        ) {
            return $true
        }
    }

    return $false
}

function Save-PhoenixPackageAcquisitionSource {

    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Source,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$DestinationPath,

        [Parameter(Mandatory)]
        [PhoenixPackageAcquisitionRequest]$Request
    )

    if ($Source.Kind -eq 'Local') {
        if (
            -not (
                Test-Path `
                    -LiteralPath $Source.Value `
                    -PathType Leaf
            )
        ) {
            throw (
                "Package acquisition source was not found: " +
                $Source.Value
            )
        }

        $sourceItem =
            Get-Item `
                -LiteralPath $Source.Value `
                -Force `
                -ErrorAction Stop

        if (
            (
                $sourceItem.Attributes -band
                    [IO.FileAttributes]::ReparsePoint
            ) -ne 0
        ) {
            throw 'Package acquisition sources cannot be reparse points.'
        }

        Copy-Item `
            -LiteralPath $sourceItem.FullName `
            -Destination $DestinationPath `
            -Force `
            -ErrorAction Stop

        return $DestinationPath
    }

    if ($Source.Kind -ne 'Uri') {
        throw (
            "Unsupported package acquisition source kind: " +
            $Source.Kind
        )
    }

    [uri]$sourceUri =
        [uri]$Source.Value

    [string]$allowInsecureHttpText =
        Get-PhoenixPackageAcquisitionValue `
            -InputObject $Request.Metadata `
            -Name @(
                'AllowInsecureHttp'
            )

    [bool]$allowInsecureHttp =
        $allowInsecureHttpText -match
            '^(?i:true|1|yes)$'

    if (
        $sourceUri.Scheme -eq 'http' -and
        -not $allowInsecureHttp
    ) {
        throw 'Insecure HTTP package acquisition is not permitted.'
    }

    Invoke-WebRequest `
        -Uri $sourceUri.AbsoluteUri `
        -OutFile $DestinationPath `
        -UseBasicParsing `
        -MaximumRedirection 5 `
        -TimeoutSec 300 `
        -ErrorAction Stop

    if (
        -not (
            Test-Path `
                -LiteralPath $DestinationPath `
                -PathType Leaf
        ) -or
        (Get-Item -LiteralPath $DestinationPath).Length -le 0
    ) {
        throw 'The downloaded package acquisition artifact is empty.'
    }

    return $DestinationPath
}

function New-PhoenixPackageAcquisitionOutcome {

    [CmdletBinding()]
    [OutputType([PhoenixPackageAcquisitionResult])]
    param(
        [Parameter(Mandatory)]
        [PhoenixPackageAcquisitionRequest]$Request,

        [Parameter(Mandatory)]
        [PhoenixPackageAcquisitionStatus]$Status,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Code,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Message
    )

    $result =
        [PhoenixPackageAcquisitionResult]::new()

    $result.SetPackage(
        $Request.Package
    )

    $result.Metadata['RequestId'] =
        $Request.RequestId

    $result.Metadata['ForceRefresh'] =
        $Request.ForceRefresh

    $result.Complete(
        $Status,
        $Code,
        $Message
    )

    return $result
}

function Invoke-PhoenixPackageAcquisitionCore {

    [CmdletBinding()]
    [OutputType([PhoenixPackageAcquisitionResult])]
    param(
        [Parameter(Mandatory)]
        [PhoenixPackageAcquisitionRequest]$Request,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Provider,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Handler,

        [Parameter()]
        [AllowEmptyString()]
        [string]$DefaultExtension = '',

        [Parameter()]
        [AllowEmptyCollection()]
        [string[]]$AllowedExtension = @(),

        [Parameter()]
        [switch]$UserSuppliedMediaWhenMissing
    )

    if (-not $Request.IsValid()) {
        throw 'A valid package-acquisition request is required.'
    }

    if (
        -not [string]::Equals(
            $Request.Package.Provider,
            $Provider,
            [StringComparison]::OrdinalIgnoreCase
        )
    ) {
        return New-PhoenixPackageAcquisitionOutcome `
            -Request $Request `
            -Status (
                [PhoenixPackageAcquisitionStatus]::Unsupported
            ) `
            -Code 'PHX_PACKAGE_ACQUISITION_PROVIDER_MISMATCH' `
            -Message (
                "The $Handler handler cannot acquire provider " +
                "'$($Request.Package.Provider)'."
            )
    }

    $source =
        $null

    try {
        $source =
            Resolve-PhoenixPackageAcquisitionSource `
                -Request $Request `
                -Provider $Provider
    }
    catch {
        return New-PhoenixPackageAcquisitionOutcome `
            -Request $Request `
            -Status (
                [PhoenixPackageAcquisitionStatus]::Failed
            ) `
            -Code 'PHX_PACKAGE_ACQUISITION_SOURCE_FAILED' `
            -Message (
                "Could not resolve acquisition source for " +
                "'$($Request.Package.Id)': " +
                $_.Exception.Message
            )
    }

    if ($null -eq $source) {
        if ($UserSuppliedMediaWhenMissing) {
            return New-PhoenixPackageAcquisitionOutcome `
                -Request $Request `
                -Status (
                    [PhoenixPackageAcquisitionStatus]::UserSuppliedRequired
                ) `
                -Code 'PHX_PACKAGE_ACQUISITION_MEDIA_REQUIRED' `
                -Message (
                    "A local path or direct URI is required for " +
                    "'$($Request.Package.Id)'."
                )
        }

        return New-PhoenixPackageAcquisitionOutcome `
            -Request $Request `
            -Status (
                [PhoenixPackageAcquisitionStatus]::Unavailable
            ) `
            -Code 'PHX_PACKAGE_ACQUISITION_SOURCE_UNAVAILABLE' `
            -Message (
                "No acquisition source is available for " +
                "'$($Request.Package.Id)'."
            )
    }

    $result =
        [PhoenixPackageAcquisitionResult]::new()

    $result.SetPackage(
        $Request.Package
    )

    $result.Metadata['RequestId'] =
        $Request.RequestId

    $result.Metadata['Handler'] =
        $Handler

    $result.Metadata['SourceKind'] =
        $source.Kind

    $result.Metadata['ForceRefresh'] =
        $Request.ForceRefresh

    $result.SourceUri =
        if ($source.Kind -eq 'Uri') {
            $source.Value
        }
        else {
            ''
        }

    [string]$workingDirectory =
        ''

    try {
        $workingDirectory =
            New-PhoenixPackageAcquisitionWorkingDirectory `
                -Request $Request

        $result.Metadata['WorkingDirectory'] =
            $workingDirectory

        [string]$fileName =
            Get-PhoenixPackageAcquisitionFileName `
                -Request $Request `
                -Source $source `
                -DefaultExtension $DefaultExtension

        if (
            -not (
                Test-PhoenixPackageAcquisitionExtension `
                    -FileName $fileName `
                    -AllowedExtension $AllowedExtension
            )
        ) {
            throw (
                "The acquisition artifact '$fileName' is not an " +
                "allowed $Provider package type."
            )
        }

        [string]$stagedPath =
            Join-Path `
                $workingDirectory `
                $fileName

        $null =
            Save-PhoenixPackageAcquisitionSource `
                -Source $source `
                -DestinationPath $stagedPath `
                -Request $Request

        [string]$expectedDigest =
            Get-PhoenixPackageAcquisitionValue `
                -InputObject $Request.Metadata `
                -Name @(
                    'ExpectedSHA256'
                    'SHA256'
                )

        if (
            -not [string]::IsNullOrWhiteSpace(
                $expectedDigest
            )
        ) {
            [string]$normalizedExpectedDigest =
                $expectedDigest.Trim().ToLowerInvariant()

            if (
                $normalizedExpectedDigest -notmatch
                    '^[a-f0-9]{64}$'
            ) {
                throw 'The expected SHA256 digest is invalid.'
            }

            [string]$actualDigest =
                (
                    Get-FileHash `
                        -LiteralPath $stagedPath `
                        -Algorithm SHA256 `
                        -ErrorAction Stop
                ).Hash.ToLowerInvariant()

            if ($actualDigest -cne $normalizedExpectedDigest) {
                throw (
                    'The acquired artifact did not match the ' +
                    'expected SHA256 digest.'
                )
            }
        }

        $candidateObject =
            Get-PhoenixContentObjectFromFile `
                -LiteralPath $stagedPath

        [bool]$alreadyStored =
            Test-PhoenixContentStoreObject `
                -StoreRoot $Request.ContentStoreRoot `
                -ContentObject $candidateObject

        $storedObject =
            Add-PhoenixContentStoreObject `
                -StoreRoot $Request.ContentStoreRoot `
                -LiteralPath $stagedPath `
                -Confirm:$false

        $result.SetContentObject(
            $storedObject
        )

        $result.FileName =
            $fileName

        $result.MediaType =
            Get-PhoenixPackageAcquisitionMediaType `
                -FileName $fileName

        $result.Metadata['ContentStoreRoot'] =
            $Request.ContentStoreRoot

        $result.Metadata['SourceValue'] =
            $source.Value

        if ($alreadyStored) {
            [string]$reuseCode =
                'PHX_PACKAGE_ACQUISITION_REUSED'

            [string]$reuseMessage =
                "Reused stored content for '$($Request.Package.Id)'."

            if ($Request.ForceRefresh) {
                $reuseCode =
                    'PHX_PACKAGE_ACQUISITION_REFRESH_REUSED'

                $reuseMessage =
                    (
                        "Refreshed '$($Request.Package.Id)' and " +
                        'reused identical stored content.'
                    )
            }

            $result.Complete(
                [PhoenixPackageAcquisitionStatus]::Reused,
                $reuseCode,
                $reuseMessage
            )
        }
        else {
            $result.Complete(
                [PhoenixPackageAcquisitionStatus]::Acquired,
                'PHX_PACKAGE_ACQUISITION_ACQUIRED',
                (
                    "Acquired '$($Request.Package.Id)' into the " +
                    'Phoenix content store.'
                )
            )
        }

        return $result
    }
    catch {
        $result.Errors =
            @(
                $_.Exception.Message
            )

        $result.Complete(
            [PhoenixPackageAcquisitionStatus]::Failed,
            'PHX_PACKAGE_ACQUISITION_FAILED',
            (
                "Package acquisition failed for " +
                "'$($Request.Package.Id)': " +
                $_.Exception.Message
            )
        )

        return $result
    }
    finally {
        if (
            -not $Request.PreserveWorkingDirectory -and
            -not [string]::IsNullOrWhiteSpace(
                $workingDirectory
            ) -and
            (
                Test-Path `
                    -LiteralPath $workingDirectory
            )
        ) {
            Remove-Item `
                -LiteralPath $workingDirectory `
                -Recurse `
                -Force `
                -ErrorAction SilentlyContinue
        }
    }
}

function Invoke-PhoenixNuGetPackageAcquisition {

    [CmdletBinding()]
    [OutputType([PhoenixPackageAcquisitionResult])]
    param(
        [Parameter(Mandatory)]
        [PhoenixPackageAcquisitionRequest]$Request
    )

    return Invoke-PhoenixPackageAcquisitionCore `
        -Request $Request `
        -Provider 'NuGet' `
        -Handler $MyInvocation.MyCommand.Name `
        -DefaultExtension '.nupkg' `
        -AllowedExtension @(
            '.nupkg'
        )
}

function Invoke-PhoenixPowerShellGalleryPackageAcquisition {

    [CmdletBinding()]
    [OutputType([PhoenixPackageAcquisitionResult])]
    param(
        [Parameter(Mandatory)]
        [PhoenixPackageAcquisitionRequest]$Request
    )

    return Invoke-PhoenixPackageAcquisitionCore `
        -Request $Request `
        -Provider 'PowerShell Gallery' `
        -Handler $MyInvocation.MyCommand.Name `
        -DefaultExtension '.nupkg' `
        -AllowedExtension @(
            '.nupkg'
        )
}

function Invoke-PhoenixScoopPackageAcquisition {

    [CmdletBinding()]
    [OutputType([PhoenixPackageAcquisitionResult])]
    param(
        [Parameter(Mandatory)]
        [PhoenixPackageAcquisitionRequest]$Request
    )

    return Invoke-PhoenixPackageAcquisitionCore `
        -Request $Request `
        -Provider 'Scoop' `
        -Handler $MyInvocation.MyCommand.Name
}

function Invoke-PhoenixGitHubPackageAcquisition {

    [CmdletBinding()]
    [OutputType([PhoenixPackageAcquisitionResult])]
    param(
        [Parameter(Mandatory)]
        [PhoenixPackageAcquisitionRequest]$Request
    )

    return Invoke-PhoenixPackageAcquisitionCore `
        -Request $Request `
        -Provider 'GitHub' `
        -Handler $MyInvocation.MyCommand.Name `
        -AllowedExtension @(
            '.exe'
            '.msi'
            '.msix'
            '.zip'
        )
}

function Invoke-PhoenixMsiPackageAcquisition {

    [CmdletBinding()]
    [OutputType([PhoenixPackageAcquisitionResult])]
    param(
        [Parameter(Mandatory)]
        [PhoenixPackageAcquisitionRequest]$Request
    )

    return Invoke-PhoenixPackageAcquisitionCore `
        -Request $Request `
        -Provider 'MSI' `
        -Handler $MyInvocation.MyCommand.Name `
        -DefaultExtension '.msi' `
        -AllowedExtension @(
            '.msi'
        ) `
        -UserSuppliedMediaWhenMissing
}

function Invoke-PhoenixExePackageAcquisition {

    [CmdletBinding()]
    [OutputType([PhoenixPackageAcquisitionResult])]
    param(
        [Parameter(Mandatory)]
        [PhoenixPackageAcquisitionRequest]$Request
    )

    return Invoke-PhoenixPackageAcquisitionCore `
        -Request $Request `
        -Provider 'EXE' `
        -Handler $MyInvocation.MyCommand.Name `
        -DefaultExtension '.exe' `
        -AllowedExtension @(
            '.exe'
        ) `
        -UserSuppliedMediaWhenMissing
}

function Invoke-PhoenixPackageAcquisition {

    [CmdletBinding()]
    [OutputType([PhoenixPackageAcquisitionResult])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [PhoenixPackageAcquisitionRequest]$Request
    )

    if (-not $Request.IsValid()) {
        throw 'A valid package-acquisition request is required.'
    }

    [PhoenixPackageAcquisitionAdapter[]]$catalog =
        @(
            Get-PhoenixBuiltInPackageAcquisitionAdapters
        )

    $route =
        Resolve-PhoenixPackageAcquisitionAdapter `
            -Request $Request `
            -Adapter $catalog

    if (-not $route.Resolved) {
        return New-PhoenixPackageAcquisitionOutcome `
            -Request $Request `
            -Status (
                [PhoenixPackageAcquisitionStatus]::Unsupported
            ) `
            -Code 'PHX_PACKAGE_ACQUISITION_ROUTE_UNAVAILABLE' `
            -Message $route.Message
    }

    [string]$handler =
        Get-PhoenixPackageAcquisitionValue `
            -InputObject $route.SelectedAdapter.Metadata `
            -Name @(
                'Handler'
            )

    if ([string]::IsNullOrWhiteSpace($handler)) {
        return New-PhoenixPackageAcquisitionOutcome `
            -Request $Request `
            -Status (
                [PhoenixPackageAcquisitionStatus]::Unsupported
            ) `
            -Code 'PHX_PACKAGE_ACQUISITION_HANDLER_UNAVAILABLE' `
            -Message (
                "No acquisition handler is registered for " +
                "'$($Request.Package.Provider)'."
            )
    }

    $handlerCommand =
        Get-Command `
            -Name $handler `
            -CommandType Function `
            -ErrorAction SilentlyContinue

    if ($null -eq $handlerCommand) {
        return New-PhoenixPackageAcquisitionOutcome `
            -Request $Request `
            -Status (
                [PhoenixPackageAcquisitionStatus]::Unsupported
            ) `
            -Code 'PHX_PACKAGE_ACQUISITION_HANDLER_UNAVAILABLE' `
            -Message (
                "Acquisition handler '$handler' is unavailable."
            )
    }

    [string]$handlerName =
        $handlerCommand.Name

    return & $handlerName `
        -Request $Request
}
