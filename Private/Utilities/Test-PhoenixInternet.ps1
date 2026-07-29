function Test-PhoenixInternet {

    [CmdletBinding()]
    param()

    try {

        $null = Invoke-WebRequest `
            -Uri "https://www.msftconnecttest.com/connecttest.txt" `
            -Method Head `
            -TimeoutSec 5 `
            -ErrorAction Stop

        return $true

    }
    catch {

        return $false

    }

}