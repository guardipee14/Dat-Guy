##########################################################
## Method: RepairPackageInteractive
## Legacy source line: 486
##########################################################

[Result] RepairPackageInteractive([Package]$Package) {

    return $this.NewFailure(
        "$($this.Name) does not implement interactive repair.",
        'PHX_INTERACTIVE_REPAIR_UNAVAILABLE'
    )
}

