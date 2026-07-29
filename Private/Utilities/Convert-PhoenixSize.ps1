function Convert-PhoenixSize {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [UInt64]$Bytes
    )

    switch ($Bytes) {

        {$_ -ge 1TB} {
            return "{0:N2} TB" -f ($Bytes / 1TB)
        }

        {$_ -ge 1GB} {
            return "{0:N2} GB" -f ($Bytes / 1GB)
        }

        {$_ -ge 1MB} {
            return "{0:N2} MB" -f ($Bytes / 1MB)
        }

        {$_ -ge 1KB} {
            return "{0:N2} KB" -f ($Bytes / 1KB)
        }

        default {
            return "$Bytes Bytes"
        }

    }

}