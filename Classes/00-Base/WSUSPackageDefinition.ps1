class WSUSPackageDefinition : Package {
    [string]$UpdateId
    [int]$RevisionNumber
    [string[]]$KBArticleIds
    [string]$ApprovalStatus
    [bool]$Applicable
    [bool]$Downloaded
    [bool]$Mandatory

    WSUSPackageDefinition() {
        $this.Provider = 'WSUS'
        $this.InstallerType = 'WindowsUpdate'
        $this.RequiresElevation = $true
        $this.KBArticleIds = @()
    }
}
