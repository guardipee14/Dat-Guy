##########################################################
## Method: RepairPackage
## Legacy source line: 494
##########################################################

[Result] RepairPackage([Package]$Package) {

    return $this.RepairPackage(
        $Package,
        [PhoenixInstallMode]::SilentPreferred
    )
}

