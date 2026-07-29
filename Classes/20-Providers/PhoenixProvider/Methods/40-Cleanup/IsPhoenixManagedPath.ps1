##########################################################
## Method: IsPhoenixManagedPath
## Legacy source line: 147
##########################################################

hidden [bool] IsPhoenixManagedPath(
    [string]$Path
) {

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $false
    }

    $context = Get-PhoenixContext

    if ($null -eq $context) {
        return $false
    }

    try {

        [string]$workingRoot = (
            [IO.Path]::GetFullPath(
                $context.WorkingRoot
            ).TrimEnd('\') + '\'
        )

        [string]$candidatePath = (
            [IO.Path]::GetFullPath($Path)
        )

        return $candidatePath.StartsWith(
            $workingRoot,
            [StringComparison]::OrdinalIgnoreCase
        )
    }
    catch {

        return $false
    }
}

