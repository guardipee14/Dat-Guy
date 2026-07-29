##########################################################
## Method: RepairPackageSilent
## Legacy source line: 478
##########################################################

[Result] RepairPackageSilent([Package]$Package) {

    return $this.NewFailure(
        "$($this.Name) does not implement silent repair.",
        'PHX_SILENT_REPAIR_UNAVAILABLE'
    )
}

