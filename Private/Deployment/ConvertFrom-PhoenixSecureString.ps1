function ConvertFrom-PhoenixSecureString {

    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [Security.SecureString]$SecureString
    )

    [IntPtr]$pointer = [IntPtr]::Zero

    try {
        $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString)
        return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)
    }
    finally {
        if ($pointer -ne [IntPtr]::Zero) {
            [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer)
        }
    }
}

function Protect-PhoenixSecretText {

    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter()]
        [AllowNull()]
        [string]$Text,

        [Parameter()]
        [AllowEmptyCollection()]
        [string[]]$Secret = @()
    )

    [string]$redacted = [string]$Text

    foreach ($value in @($Secret)) {
        if (-not [string]::IsNullOrWhiteSpace($value)) {
            $redacted = $redacted.Replace($value, '[REDACTED]', [StringComparison]::Ordinal)
        }
    }

    $redacted = [regex]::Replace(
        $redacted,
        '(?i)(password|product[-_ ]?key|token|secret|recovery[-_ ]?key)\s*[:=]\s*[^\s;]+',
        '$1=[REDACTED]'
    )

    return $redacted
}
