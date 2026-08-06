function Resolve-PhoenixContentStoreObjectPath {

    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$StoreRoot,

        [Parameter(Mandatory)]
        [PhoenixContentAddress]$Address
    )

    if ($null -eq $Address) {
        throw 'A Phoenix content address is required.'
    }

    if (-not $Address.IsValid()) {
        throw 'The Phoenix content address is invalid.'
    }

    [string]$resolvedRoot =
        [IO.Path]::GetFullPath(
            $StoreRoot
        )

    [string]$nativeRelativePath =
        $Address.RelativePath.Replace(
            [char]'/',
            [IO.Path]::DirectorySeparatorChar
        )

    if (
        [IO.Path]::IsPathRooted(
            $nativeRelativePath
        )
    ) {
        throw 'The content-store object path must be relative.'
    }

    [string]$objectPath =
        [IO.Path]::GetFullPath(
            (
                Join-Path `
                    -Path $resolvedRoot `
                    -ChildPath $nativeRelativePath
            )
        )

    [string]$rootBoundary =
        $resolvedRoot.TrimEnd(
            [char[]]@(
                '\'
                '/'
            )
        ) +
        [IO.Path]::DirectorySeparatorChar

    if (
        -not $objectPath.StartsWith(
            $rootBoundary,
            [StringComparison]::OrdinalIgnoreCase
        )
    ) {
        throw (
            "Content-store object path escapes the store root: " +
            $objectPath
        )
    }

    return $objectPath
}