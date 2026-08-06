function Test-PhoenixContentStoreObject {

    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$StoreRoot,

        [Parameter(Mandatory)]
        [PhoenixContentObject]$ContentObject
    )

    if ($null -eq $ContentObject) {
        throw 'A Phoenix content object is required.'
    }

    if (-not $ContentObject.IsValid()) {
        throw 'The Phoenix content object is invalid.'
    }

    $address =
        [PhoenixContentAddress]::new(
            $ContentObject.Digest
        )

    [string]$objectPath =
        Resolve-PhoenixContentStoreObjectPath `
            -StoreRoot $StoreRoot `
            -Address $address

    if (
        -not (
            Test-Path `
                -LiteralPath $objectPath `
                -PathType Leaf
        )
    ) {
        return $false
    }

    [IO.FileInfo]$storedFile =
        Get-Item `
            -LiteralPath $objectPath `
            -Force `
            -ErrorAction Stop

    if (
        (
            $storedFile.Attributes -band
                [IO.FileAttributes]::ReparsePoint
        ) -ne 0
    ) {
        return $false
    }

    if (
        $storedFile.Length -ne
            $ContentObject.Length
    ) {
        return $false
    }

    [string]$storedDigest =
        (
            Get-FileHash `
                -LiteralPath $objectPath `
                -Algorithm SHA256 `
                -ErrorAction Stop
        ).Hash.ToLowerInvariant()

    return (
        $storedDigest -ceq
            $ContentObject.Digest
    )
}