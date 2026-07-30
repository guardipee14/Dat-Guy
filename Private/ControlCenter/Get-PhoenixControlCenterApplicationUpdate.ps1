function ConvertFrom-PhoenixControlCenterTable {

    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]]$Line
    )

    [int]$separatorIndex = -1
    $columnMatches = @()

    for (
        [int]$lineIndex = 0;
        $lineIndex -lt $Line.Count;
        $lineIndex++
    ) {
        $matches = @(
            [regex]::Matches(
                [string]$Line[$lineIndex],
                '-{2,}'
            )
        )

        if ($matches.Count -ge 4) {
            $separatorIndex = $lineIndex
            $columnMatches = $matches
            break
        }
    }

    if ($separatorIndex -lt 0) {
        return @()
    }

    $records =
        [System.Collections.Generic.List[object]]::new()

    for (
        [int]$lineIndex = $separatorIndex + 1;
        $lineIndex -lt $Line.Count;
        $lineIndex++
    ) {
        [string]$currentLine = [string]$Line[$lineIndex]

        if ([string]::IsNullOrWhiteSpace($currentLine)) {
            continue
        }

        $values =
            [System.Collections.Generic.List[string]]::new()

        for (
            [int]$columnIndex = 0;
            $columnIndex -lt $columnMatches.Count;
            $columnIndex++
        ) {
            [int]$start = $columnMatches[$columnIndex].Index
            [int]$length = if (
                $columnIndex -lt
                ($columnMatches.Count - 1)
            ) {
                $columnMatches[$columnIndex + 1].Index -
                    $start
            }
            else {
                $currentLine.Length - $start
            }

            if ($start -ge $currentLine.Length) {
                $values.Add('')
                continue
            }

            $length =
                [Math]::Min(
                    $length,
                    $currentLine.Length - $start
                )

            $values.Add(
                $currentLine.Substring(
                    $start,
                    $length
                ).Trim()
            )
        }

        if ($values.Count -ge 4) {
            $records.Add($values.ToArray())
        }
    }

    return $records.ToArray()
}

function Get-PhoenixControlCenterApplicationUpdate {

    [CmdletBinding()]
    [OutputType([pscustomobject[]])]
    param()

    $updates =
        [System.Collections.Generic.List[object]]::new()

    $wingetCommand =
        Get-Command `
            -Name winget `
            -CommandType Application `
            -ErrorAction SilentlyContinue |
            Select-Object -First 1

    if ($null -ne $wingetCommand) {
        try {
            $wingetOutput = @(
                & $wingetCommand.Source `
                    list `
                    --upgrade-available `
                    --accept-source-agreements `
                    --disable-interactivity `
                    2>&1 |
                    ForEach-Object {
                        $_.ToString()
                    }
            )

            foreach (
                $row in @(
                    ConvertFrom-PhoenixControlCenterTable `
                        -Line $wingetOutput
                )
            ) {
                if (
                    $row.Count -lt 4 -or
                    [string]::IsNullOrWhiteSpace($row[1])
                ) {
                    continue
                }

                $updates.Add(
                    [pscustomobject]@{
                        Name             = $row[0]
                        Id               = $row[1]
                        Provider         = 'WinGet'
                        CurrentVersion   = $row[2]
                        AvailableVersion = $row[3]
                        Source           = if ($row.Count -ge 5) {
                            $row[4]
                        }
                        else {
                            'winget'
                        }
                        UpdateAvailable  = $true
                        UpdateStatus     = 'Update available'
                    }
                )
            }
        }
        catch {
            Write-Warning (
                'WinGet update discovery failed: {0}' -f
                $_.Exception.Message
            )
        }
    }

    $chocolateyCommand =
        Get-Command `
            -Name choco `
            -CommandType Application `
            -ErrorAction SilentlyContinue |
            Select-Object -First 1

    if ($null -ne $chocolateyCommand) {
        try {
            $chocolateyOutput = @(
                & $chocolateyCommand.Source `
                    outdated `
                    --limit-output `
                    --no-color `
                    --ignore-unfound `
                    2>&1 |
                    ForEach-Object {
                        $_.ToString()
                    }
            )

            foreach ($line in $chocolateyOutput) {
                if (
                    [string]::IsNullOrWhiteSpace($line) -or
                    $line -notmatch '\|'
                ) {
                    continue
                }

                $parts = @($line -split '\|')

                if (
                    $parts.Count -lt 3 -or
                    [string]::IsNullOrWhiteSpace($parts[0])
                ) {
                    continue
                }

                $updates.Add(
                    [pscustomobject]@{
                        Name             = $parts[0]
                        Id               = $parts[0]
                        Provider         = 'Chocolatey'
                        CurrentVersion   = $parts[1]
                        AvailableVersion = $parts[2]
                        Source           = 'chocolatey'
                        UpdateAvailable  = $true
                        UpdateStatus     = if (
                            $parts.Count -ge 4 -and
                            $parts[3] -match 'true'
                        ) {
                            'Pinned'
                        }
                        else {
                            'Update available'
                        }
                    }
                )
            }
        }
        catch {
            Write-Warning (
                'Chocolatey update discovery failed: {0}' -f
                $_.Exception.Message
            )
        }
    }

    return @(
        $updates |
            Sort-Object `
                -Property Provider, Id `
                -Unique
    )
}
