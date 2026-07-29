using module .\Classes\Phoenix.Classes.psm1

$r = [Result]::new()
$r

$p = [Package]::new()
$p

$d = [Driver]::new()
$d

$l = [PhoenixLogger]::new($PWD.Path)
$l

$c = [PhoenixConfiguration]::new($PWD.Path)
$c

$ctx = [PhoenixContext]::new($PWD.Path)

$ctx | Format-List *