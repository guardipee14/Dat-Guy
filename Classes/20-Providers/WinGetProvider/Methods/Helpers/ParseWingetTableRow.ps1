##########################################################
## Method: ParseWingetTableRow
## Legacy source line: 56
##########################################################

hidden [string[]] ParseWingetTableRow(
        [string]$Line,
        [int[]]$ColumnStarts
) {

    $values = [System.Collections.Generic.List[string]]::new()

    if (
        [string]::IsNullOrWhiteSpace($Line) -or
        $null -eq $ColumnStarts -or
        $ColumnStarts.Count -eq 0
    ) {

        return $values.ToArray()
    }

    for (
        [int]$columnIndex = 0
        $columnIndex -lt $ColumnStarts.Count
        $columnIndex++
    ) {

        [int]$startIndex = $ColumnStarts[$columnIndex]

        if ($Line.Length -le $startIndex) {

            $values.Add('')

            continue
        }

        if ($columnIndex -lt ($ColumnStarts.Count - 1)) {

            [int]$nextStart = $ColumnStarts[$columnIndex + 1]
            [int]$length = $nextStart - $startIndex

            if ($length -lt 0) {
                $length = 0
            }

            [int]$remainingLength = $Line.Length - $startIndex

            if ($length -gt $remainingLength) {
                $length = $remainingLength
            }

            [string]$value = $Line.Substring(
                $startIndex,
                $length
            ).Trim()

            $values.Add($value)
        }
        else {

            [string]$value = $Line.Substring(
                $startIndex
            ).Trim()

            $values.Add($value)
        }
    }

    return $values.ToArray()
}

