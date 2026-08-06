class PhoenixContentObject {

    [string]$ObjectId
    [string]$Algorithm
    [string]$Digest
    [string]$RelativePath
    [long]$Length

    PhoenixContentObject() {

        $this.ObjectId = ''
        $this.Algorithm = 'SHA256'
        $this.Digest = ''
        $this.RelativePath = ''
        $this.Length = -1
    }

    PhoenixContentObject(
        [PhoenixContentAddress]$Address,
        [long]$Length
    ) {

        $this.ObjectId = ''
        $this.Algorithm = 'SHA256'
        $this.Digest = ''
        $this.RelativePath = ''
        $this.Length = -1

        $this.SetAddress(
            $Address
        )

        $this.SetLength(
            $Length
        )
    }

    [void] SetAddress(
        [PhoenixContentAddress]$Address
    ) {

        if ($null -eq $Address) {
            throw 'A Phoenix content address is required.'
        }

        if (-not $Address.IsValid()) {
            throw 'The Phoenix content address is invalid.'
        }

        $this.ObjectId =
            $Address.ObjectId

        $this.Algorithm =
            $Address.Algorithm

        $this.Digest =
            $Address.Digest

        $this.RelativePath =
            $Address.RelativePath
    }

    [void] SetLength(
        [long]$Length
    ) {

        if ($Length -lt 0) {
            throw 'Content length cannot be negative.'
        }

        $this.Length = $Length
    }

    [bool] IsValid() {

        if ($this.Length -lt 0) {
            return $false
        }

        $address =
            [PhoenixContentAddress]::new()

        $address.ObjectId =
            $this.ObjectId

        $address.Algorithm =
            $this.Algorithm

        $address.Digest =
            $this.Digest

        $address.RelativePath =
            $this.RelativePath

        return $address.IsValid()
    }
}