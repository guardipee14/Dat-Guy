class GitHubReleasePackageDefinition : EXEPackageDefinition {
    [string]$Repository
    [string]$ReleaseTag
    [string]$ReleaseName
    [string]$AssetName
    [string]$AssetPattern
    [string]$DownloadUri
    [string]$ChecksumUri
    [string]$SHA256
    [string]$InstalledVersion
    [string]$DetectionDisplayName
    [string]$ReleaseNotes
    [string]$ReleaseNotesUrl
    [datetime]$PublishedAtUtc

    GitHubReleasePackageDefinition() {
        $this.Provider = 'GitHub Releases'
        $this.Source = 'github.com'
    }
}
