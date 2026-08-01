function Get-PhoenixControlCenterPackageRelease {

    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Id,

        [Parameter(Mandatory)]
        [ValidateSet(
            'WinGet',
            'Chocolatey',
            'GitHub Releases'
        )]
        [string]$Provider,

        [Parameter()]
        [AllowEmptyString()]
        [string]$Version = ''
    )

    $output = @()
    [string]$sourceUrl = ''
    [string]$metadataStatus =
        'Not provided by publisher'

    try {
        switch ($Provider) {
            'WinGet' {
                $command =
                    Get-Command `
                        -Name winget `
                        -CommandType Application `
                        -ErrorAction Stop |
                        Select-Object -First 1

                $arguments = @(
                    'show'
                    '--id'
                    $Id
                    '--exact'
                    '--source'
                    'winget'
                    '--accept-source-agreements'
                    '--disable-interactivity'
                )

                if (-not [string]::IsNullOrWhiteSpace($Version)) {
                    $arguments += @(
                        '--version'
                        $Version
                    )
                }

                $output = @(
                    & $command.Source @arguments 2>&1 |
                        ForEach-Object {
                            $_.ToString()
                        }
                )
            }

            'Chocolatey' {
                $command =
                    Get-Command `
                        -Name choco `
                        -CommandType Application `
                        -ErrorAction Stop |
                        Select-Object -First 1

                $arguments = @(
                    'info'
                    $Id
                    '--no-color'
                )

                if (-not [string]::IsNullOrWhiteSpace($Version)) {
                    $arguments += @(
                        '--version'
                        $Version
                    )
                }

                $output = @(
                    & $command.Source @arguments 2>&1 |
                        ForEach-Object {
                            $_.ToString()
                        }
                )
            }

            'GitHub Releases' {
                $headers = @{
                    Accept = 'application/vnd.github+json'
                    'User-Agent' = 'PhoenixDeploy'
                    'X-GitHub-Api-Version' = '2022-11-28'
                }
                if (-not [string]::IsNullOrWhiteSpace($env:GITHUB_TOKEN)) {
                    $headers.Authorization = "Bearer $($env:GITHUB_TOKEN)"
                }
                $release = Invoke-RestMethod `
                    -Uri "https://api.github.com/repos/$Id/releases/latest" `
                    -Headers $headers `
                    -Method Get `
                    -ErrorAction Stop

                return [pscustomobject]@{
                    Id               = $Id
                    Provider         = $Provider
                    Version          = ([string]$release.tag_name).TrimStart('v', 'V')
                    MetadataStatus   = 'Publisher metadata available'
                    ReleaseNotes     = [string]$release.body
                    ReleaseNotesUrl  = [string]$release.html_url
                    ProviderMetadata = [string]$release.name
                    Error            = ''
                }
            }
        }
    }
    catch {
        return [pscustomobject]@{
            Id               = $Id
            Provider         = $Provider
            Version          = $Version
            MetadataStatus   = 'Metadata lookup failed'
            ReleaseNotes     = ''
            ReleaseNotesUrl  = ''
            ProviderMetadata = ''
            Error            = $_.Exception.Message
        }
    }

    [int]$metadataExitCode = $LASTEXITCODE

    if ($metadataExitCode -ne 0) {
        return [pscustomobject]@{
            Id               = $Id
            Provider         = $Provider
            Version          = $Version
            MetadataStatus   = 'Metadata lookup failed'
            ReleaseNotes     = ''
            ReleaseNotesUrl  = ''
            ProviderMetadata = ($output -join [Environment]::NewLine)
            Error            =
                "$Provider metadata command exited with code $metadataExitCode."
        }
    }

    [string]$providerMetadata = (
        $output -join [Environment]::NewLine
    )

    $providerMetadata = [regex]::Replace(
        $providerMetadata,
        [char]27 + '\[[0-?]*[ -/]*[@-~]',
        ''
    ).Trim()

    foreach ($line in $output) {
        if (
            $line -match
            '(?i)(?:release\s*notes?\s*(?:url)?|homepage|package\s*source)\s*:\s*(https?://\S+)'
        ) {
            $sourceUrl = $Matches[1].TrimEnd(
                ')',
                ']',
                '.',
                ','
            )

            break
        }
    }

    [string]$releaseNotes = ''

    if (
        $providerMetadata -match
        '(?im)^\s*Release\s+Notes?\s*:\s*(.+)$'
    ) {
        $releaseNotes = $Matches[1].Trim()
    }

    if (
        -not [string]::IsNullOrWhiteSpace($releaseNotes) -or
        -not [string]::IsNullOrWhiteSpace($sourceUrl)
    ) {
        $metadataStatus = 'Publisher metadata available'
    }

    return [pscustomobject]@{
        Id               = $Id
        Provider         = $Provider
        Version          = $Version
        MetadataStatus   = $metadataStatus
        ReleaseNotes     = $releaseNotes
        ReleaseNotesUrl  = $sourceUrl
        ProviderMetadata = $providerMetadata
        Error            = ''
    }
}
