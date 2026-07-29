$Output = Join-Path $PSScriptRoot '..\Classes\Phoenix.Classes.ps1'

@(
    '# -----------------------------------------------------------------'
    '# AUTO-GENERATED FILE'
    '# DO NOT EDIT'
    '# -----------------------------------------------------------------'
    ''
) | Set-Content $Output

Get-ChildItem (Join-Path $PSScriptRoot '..\Classes') -Directory |
    Sort-Object Name |
    ForEach-Object {

        Get-ChildItem $_.FullName -Filter *.ps1 |
            Sort-Object Name |
            ForEach-Object {

                Add-Content $Output "#region $($_.Directory.Name)\$($_.Name)"
                Get-Content $_.FullName | Add-Content $Output
                Add-Content $Output "#endregion"
                Add-Content $Output ""

            }

    }