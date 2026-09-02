function Find-PhoenixOfflineDriverMatch {

    [CmdletBinding()]
    [OutputType([pscustomobject[]])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [PhoenixOfflineDriverPackage[]]$Package,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [PhoenixDriverHardwareIdentity]$TargetIdentity
    )

    if (-not $TargetIdentity.IsValid()) {
        throw 'A valid target hardware identity is required.'
    }

    $targetHardware =
        [Collections.Generic.HashSet[string]]::new(
            [StringComparer]::OrdinalIgnoreCase
        )

    $targetCompatible =
        [Collections.Generic.HashSet[string]]::new(
            [StringComparer]::OrdinalIgnoreCase
        )

    foreach ($identifier in $TargetIdentity.HardwareIds) {
        $null = $targetHardware.Add($identifier)
    }

    foreach ($identifier in $TargetIdentity.CompatibleIds) {
        $null = $targetCompatible.Add($identifier)
    }

    $driverMatches = foreach ($candidate in $Package) {
        if ($null -eq $candidate -or -not $candidate.IsValid()) {
            continue
        }

        [string]$matchedIdentifier = ''
        [string]$matchType = ''
        [int]$score = 0

        foreach ($identifier in $candidate.HardwareIds) {
            if ($targetHardware.Contains($identifier)) {
                $matchedIdentifier = $identifier
                $matchType = 'HardwareId'
                $score = 200000 + $identifier.Length
                break
            }
        }

        if ($score -eq 0) {
            foreach ($identifier in $candidate.CompatibleIds) {
                if (
                    $targetHardware.Contains($identifier) -or
                    $targetCompatible.Contains($identifier)
                ) {
                    $matchedIdentifier = $identifier
                    $matchType = 'CompatibleId'
                    $score = 100000 + $identifier.Length
                    break
                }
            }
        }

        if ($score -eq 0) {
            continue
        }

        if (
            -not [string]::IsNullOrWhiteSpace($candidate.ClassGuid) -and
            [string]::Equals(
                $candidate.ClassGuid,
                $TargetIdentity.ClassGuid,
                [StringComparison]::OrdinalIgnoreCase
            )
        ) {
            $score += 1000
        }

        [pscustomobject]@{
            Package = $candidate
            PackageId = $candidate.PackageId
            InfName = $candidate.InfName
            MatchType = $matchType
            MatchedIdentifier = $matchedIdentifier
            Score = $score
            DriverDate = $candidate.DriverDate
            Version = $candidate.Version
        }
    }

    return @(
        $driverMatches |
            Sort-Object `
                -Property @(
                    @{ Expression = 'Score'; Descending = $true }
                    @{ Expression = 'DriverDate'; Descending = $true }
                    @{ Expression = 'Version'; Descending = $true }
                    @{ Expression = 'PackageId'; Descending = $false }
                )
    )
}
