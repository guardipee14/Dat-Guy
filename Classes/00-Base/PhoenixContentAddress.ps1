class PhoenixContentAddress {

    [string]$Algorithm
    [string]$Digest
    [string]$ObjectId
    [string]$RelativePath

    PhoenixContentAddress() {

        $this.Algorithm = 'SHA256'
        $this.Digest = ''
        $this.ObjectId = ''
        $this.RelativePath = ''
    }

    PhoenixContentAddress(
        [string]$Digest
    ) {

        $this.Algorithm = 'SHA256'

        $this.SetDigest(
            $Digest
        )
    }

    [void] SetDigest(
        [string]$Digest
    ) {

        if ([string]::IsNullOrWhiteSpace($Digest)) {
            throw 'A SHA-256 digest is required.'
        }

        [string]$normalizedDigest =
            $Digest.Trim().ToLowerInvariant()

        if (
            $normalizedDigest -notmatch
                '^[0-9a-f]{64}$'
        ) {
            throw (
                'A SHA-256 digest must contain exactly ' +
                '64 hexadecimal characters.'
            )
        }

        $this.Algorithm = 'SHA256'
        $this.Digest = $normalizedDigest
        $this.ObjectId =
            'sha256:{0}' -f
                $normalizedDigest

        $this.RelativePath =
            'objects/sha256/{0}/{1}' -f
                $normalizedDigest.Substring(
                    0,
                    2
                ),
                $normalizedDigest.Substring(
                    2
                )
    }

    [bool] IsValid() {

        if ($this.Algorithm -cne 'SHA256') {
            return $false
        }

        if (
            $this.Digest -cnotmatch
                '^[0-9a-f]{64}$'
        ) {
            return $false
        }

        [string]$expectedObjectId =
            'sha256:{0}' -f
                $this.Digest

        if ($this.ObjectId -cne $expectedObjectId) {
            return $false
        }

        [string]$expectedRelativePath =
            'objects/sha256/{0}/{1}' -f
                $this.Digest.Substring(
                    0,
                    2
                ),
                $this.Digest.Substring(
                    2
                )

        return (
            $this.RelativePath -ceq
                $expectedRelativePath
        )
    }
}