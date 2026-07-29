class Result {

    [bool]$Success

    [string]$Message

    [string]$Code

    [object]$Data

    [object[]]$Warnings

    [object[]]$Errors

    [datetime]$Timestamp

    Result() {

        $this.Timestamp = Get-Date
        $this.Warnings = @()
        $this.Errors = @()

    }

    static [Result] Success() {

    $r = [Result]::new()

    $r.Success = $true

    return $r
}

static [Result] Success(
    [object]$Data
) {

    $r = [Result]::new()

    $r.Success = $true
    $r.Data = $Data

    return $r
}

    static [Result] Failure(
        [string]$Message
    ) {

        $r = [Result]::new()

        $r.Success = $false
        $r.Message = $Message

        return $r

    }

}