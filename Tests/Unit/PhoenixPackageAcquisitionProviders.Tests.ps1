BeforeAll {
    $projectRoot =
        (
            Resolve-Path `
                (Join-Path $PSScriptRoot '..\..')
        ).Path

    Import-Module `
        (Join-Path $projectRoot 'Phoenix.psd1') `
        -Force `
        6>$null
}

AfterAll {
    Remove-Module `
        Phoenix `
        -Force `
        -ErrorAction SilentlyContinue
}

Describe 'Phoenix package acquisition completion bundle' -Tag @(
    'Unit'
    'OfflineBundle'
    'ApplicationAcquisition'
    'Providers'
) {
    It 'registers an implemented handler for every built-in adapter' {
        InModuleScope Phoenix {
            $adapters =
                @(
                    Get-PhoenixBuiltInPackageAcquisitionAdapters
                )

            $adapters.Count |
                Should-Be 6

            foreach ($adapter in $adapters) {
                $adapter.Metadata['ImplementationStatus'] |
                    Should-Be 'Implemented'

                [string]::IsNullOrWhiteSpace(
                    [string]$adapter.Metadata['Handler']
                ) |
                    Should-BeFalse

                $handlerCommand =
                    Get-Command `
                        -Name ([string]$adapter.Metadata['Handler']) `
                        -CommandType Function `
                        -ErrorAction SilentlyContinue

                ($null -ne $handlerCommand) |
                    Should-BeTrue
            }
        }
    }

    It 'uses the PowerShell provider installer types produced by inventory' {
        InModuleScope Phoenix {
            $adapter =
                @(
                    Get-PhoenixBuiltInPackageAcquisitionAdapters |
                        Where-Object {
                            $_.Provider -eq 'PowerShell Gallery'
                        }
                )[0]

            ($adapter.SupportedInstallerTypes -join '|') |
                Should-Be 'PowerShellModule|PowerShellScript'

            $adapter.SupportedSources.Count |
                Should-Be 0
        }
    }

    It 'acquires NuGet media from a local source without internet access' {
        InModuleScope Phoenix {
            [string]$root =
                Join-Path `
                    ([IO.Path]::GetTempPath()) `
                    ('Phoenix-Acquisition-Test-' + [guid]::NewGuid().ToString('N'))

            try {
                $null = New-Item -ItemType Directory -Path $root -Force
                [string]$sourcePath = Join-Path $root 'example.nupkg'
                [IO.File]::WriteAllText($sourcePath, 'nuget-fixture')

                $package = [Package]::new()
                $package.Id = 'Example.NuGet'
                $package.Version = '1.0.0'
                $package.Provider = 'NuGet'
                $package.InstallerType = 'NuGet'

                $request = [PhoenixPackageAcquisitionRequest]::new()
                $request.SetPackage($package)
                [string]$storeRoot = Join-Path $root 'store'
                $request.SetContentStoreRoot($storeRoot)
                $request.Metadata['SourcePath'] = $sourcePath

                $result = Invoke-PhoenixPackageAcquisition -Request $request

                $result.Success | Should-BeTrue
                $result.Status | Should-Be ([PhoenixPackageAcquisitionStatus]::Acquired)
                $result.FileName | Should-Be 'example.nupkg'
                $result.ContentObject.IsValid() | Should-BeTrue
                $result.IsValid() | Should-BeTrue
            }
            finally {
                Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    It 'acquires PowerShell Gallery media from a supplied package file' {
        InModuleScope Phoenix {
            [string]$root = Join-Path ([IO.Path]::GetTempPath()) ('Phoenix-Acquisition-Test-' + [guid]::NewGuid().ToString('N'))
            try {
                $null = New-Item -ItemType Directory -Path $root -Force
                [string]$sourcePath = Join-Path $root 'example.nupkg'
                [IO.File]::WriteAllText($sourcePath, 'gallery-fixture')

                $package = [Package]::new()
                $package.Id = 'ExampleGalleryModule'
                $package.Version = '2.0.0'
                $package.Provider = 'PowerShell Gallery'
                $package.Source = 'PrivateRepository'
                $package.InstallerType = 'PowerShellModule'

                $request = [PhoenixPackageAcquisitionRequest]::new()
                $request.SetPackage($package)
                [string]$storeRoot = Join-Path $root 'store'
                $request.SetContentStoreRoot($storeRoot)
                $request.Metadata['SourcePath'] = $sourcePath

                $result = Invoke-PhoenixPackageAcquisition -Request $request

                $result.Success | Should-BeTrue
                $result.Provider | Should-Be 'PowerShell Gallery'
                $result.MediaType | Should-Be 'application/zip'
            }
            finally {
                Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    It 'acquires Scoop cache media from a supplied cache path' {
        InModuleScope Phoenix {
            [string]$root = Join-Path ([IO.Path]::GetTempPath()) ('Phoenix-Acquisition-Test-' + [guid]::NewGuid().ToString('N'))
            try {
                $null = New-Item -ItemType Directory -Path $root -Force
                [string]$sourcePath = Join-Path $root 'example#1.0.0#fixture'
                [IO.File]::WriteAllText($sourcePath, 'scoop-fixture')

                $package = [Package]::new()
                $package.Id = 'example'
                $package.Version = '1.0.0'
                $package.Provider = 'Scoop'
                $package.InstallerType = 'Scoop'

                $request = [PhoenixPackageAcquisitionRequest]::new()
                $request.SetPackage($package)
                [string]$storeRoot = Join-Path $root 'store'
                $request.SetContentStoreRoot($storeRoot)
                $request.Metadata['CachePath'] = $sourcePath

                $result = Invoke-PhoenixPackageAcquisition -Request $request

                $result.Success | Should-BeTrue
                $result.Provider | Should-Be 'Scoop'
                $result.ContentObject.Length | Should-Be 13
            }
            finally {
                Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    It 'acquires GitHub release media from a supplied release asset' {
        InModuleScope Phoenix {
            [string]$root = Join-Path ([IO.Path]::GetTempPath()) ('Phoenix-Acquisition-Test-' + [guid]::NewGuid().ToString('N'))
            try {
                $null = New-Item -ItemType Directory -Path $root -Force
                [string]$sourcePath = Join-Path $root 'setup.zip'
                [IO.File]::WriteAllText($sourcePath, 'github-fixture')

                $package = [Package]::new()
                $package.Id = 'owner/repository'
                $package.Version = 'v1.0.0'
                $package.Provider = 'GitHub'
                $package.InstallerType = 'ZIP'

                $request = [PhoenixPackageAcquisitionRequest]::new()
                $request.SetPackage($package)
                [string]$storeRoot = Join-Path $root 'store'
                $request.SetContentStoreRoot($storeRoot)
                $request.Metadata['AssetPath'] = $sourcePath

                $result = Invoke-PhoenixPackageAcquisition -Request $request

                $result.Success | Should-BeTrue
                $result.Provider | Should-Be 'GitHub'
                $result.FileName | Should-Be 'setup.zip'
            }
            finally {
                Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    It 'acquires MSI installer media from a local path' {
        InModuleScope Phoenix {
            [string]$root = Join-Path ([IO.Path]::GetTempPath()) ('Phoenix-Acquisition-Test-' + [guid]::NewGuid().ToString('N'))
            try {
                $null = New-Item -ItemType Directory -Path $root -Force
                [string]$sourcePath = Join-Path $root 'setup.msi'
                [IO.File]::WriteAllText($sourcePath, 'msi-fixture')

                $package = [Package]::new()
                $package.Id = 'Example.MSI'
                $package.Version = '1.0.0'
                $package.Provider = 'MSI'
                $package.InstallerType = 'MSI'

                $request = [PhoenixPackageAcquisitionRequest]::new()
                $request.SetPackage($package)
                [string]$storeRoot = Join-Path $root 'store'
                $request.SetContentStoreRoot($storeRoot)
                $request.Metadata['LocalPath'] = $sourcePath

                $result = Invoke-PhoenixPackageAcquisition -Request $request

                $result.Success | Should-BeTrue
                $result.MediaType | Should-Be 'application/x-msi'
            }
            finally {
                Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    It 'acquires EXE installer media from a local path' {
        InModuleScope Phoenix {
            [string]$root = Join-Path ([IO.Path]::GetTempPath()) ('Phoenix-Acquisition-Test-' + [guid]::NewGuid().ToString('N'))
            try {
                $null = New-Item -ItemType Directory -Path $root -Force
                [string]$sourcePath = Join-Path $root 'setup.exe'
                [IO.File]::WriteAllText($sourcePath, 'exe-fixture')

                $package = [Package]::new()
                $package.Id = 'Example.EXE'
                $package.Version = '1.0.0'
                $package.Provider = 'EXE'
                $package.InstallerType = 'EXE'

                $request = [PhoenixPackageAcquisitionRequest]::new()
                $request.SetPackage($package)
                [string]$storeRoot = Join-Path $root 'store'
                $request.SetContentStoreRoot($storeRoot)
                $request.Metadata['LocalPath'] = $sourcePath

                $result = Invoke-PhoenixPackageAcquisition -Request $request

                $result.Success | Should-BeTrue
                $result.MediaType | Should-Be 'application/vnd.microsoft.portable-executable'
            }
            finally {
                Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    It 'reuses identical content already in the content-addressed store' {
        InModuleScope Phoenix {
            [string]$root = Join-Path ([IO.Path]::GetTempPath()) ('Phoenix-Acquisition-Test-' + [guid]::NewGuid().ToString('N'))
            try {
                $null = New-Item -ItemType Directory -Path $root -Force
                [string]$sourcePath = Join-Path $root 'example.nupkg'
                [IO.File]::WriteAllText($sourcePath, 'reuse-fixture')

                $package = [Package]::new()
                $package.Id = 'Example.Reuse'
                $package.Version = '1.0.0'
                $package.Provider = 'NuGet'
                $package.InstallerType = 'NuGet'

                $request = [PhoenixPackageAcquisitionRequest]::new()
                $request.SetPackage($package)
                [string]$storeRoot = Join-Path $root 'store'
                $request.SetContentStoreRoot($storeRoot)
                $request.Metadata['SourcePath'] = $sourcePath

                $first = Invoke-PhoenixPackageAcquisition -Request $request
                $second = Invoke-PhoenixPackageAcquisition -Request $request

                $first.Status | Should-Be ([PhoenixPackageAcquisitionStatus]::Acquired)
                $second.Status | Should-Be ([PhoenixPackageAcquisitionStatus]::Reused)
                $second.ContentObject.ObjectId | Should-Be $first.ContentObject.ObjectId
            }
            finally {
                Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    It 'reports refresh reuse when ForceRefresh returns identical bytes' {
        InModuleScope Phoenix {
            [string]$root = Join-Path ([IO.Path]::GetTempPath()) ('Phoenix-Acquisition-Test-' + [guid]::NewGuid().ToString('N'))
            try {
                $null = New-Item -ItemType Directory -Path $root -Force
                [string]$sourcePath = Join-Path $root 'example.nupkg'
                [IO.File]::WriteAllText($sourcePath, 'refresh-fixture')

                $package = [Package]::new()
                $package.Id = 'Example.Refresh'
                $package.Version = '1.0.0'
                $package.Provider = 'NuGet'
                $package.InstallerType = 'NuGet'

                $request = [PhoenixPackageAcquisitionRequest]::new()
                $request.SetPackage($package)
                [string]$storeRoot = Join-Path $root 'store'
                $request.SetContentStoreRoot($storeRoot)
                $request.Metadata['SourcePath'] = $sourcePath

                $null = Invoke-PhoenixPackageAcquisition -Request $request
                $request.ForceRefresh = $true
                $result = Invoke-PhoenixPackageAcquisition -Request $request

                $result.Status | Should-Be ([PhoenixPackageAcquisitionStatus]::Reused)
                $result.Code | Should-Be 'PHX_PACKAGE_ACQUISITION_REFRESH_REUSED'
                $result.Metadata['ForceRefresh'] | Should-BeTrue
            }
            finally {
                Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    It 'accepts a matching expected SHA256 digest' {
        InModuleScope Phoenix {
            [string]$root = Join-Path ([IO.Path]::GetTempPath()) ('Phoenix-Acquisition-Test-' + [guid]::NewGuid().ToString('N'))
            try {
                $null = New-Item -ItemType Directory -Path $root -Force
                [string]$sourcePath = Join-Path $root 'setup.exe'
                [IO.File]::WriteAllText($sourcePath, 'hash-fixture')
                [string]$digest = (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash

                $package = [Package]::new()
                $package.Id = 'Example.Hash'
                $package.Provider = 'EXE'
                $package.InstallerType = 'EXE'

                $request = [PhoenixPackageAcquisitionRequest]::new()
                $request.SetPackage($package)
                [string]$storeRoot = Join-Path $root 'store'
                $request.SetContentStoreRoot($storeRoot)
                $request.Metadata['SourcePath'] = $sourcePath
                $request.Metadata['ExpectedSHA256'] = $digest

                $result = Invoke-PhoenixPackageAcquisition -Request $request

                $result.Success | Should-BeTrue
                $result.IsValid() | Should-BeTrue
            }
            finally {
                Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    It 'fails acquisition when expected SHA256 does not match' {
        InModuleScope Phoenix {
            [string]$root = Join-Path ([IO.Path]::GetTempPath()) ('Phoenix-Acquisition-Test-' + [guid]::NewGuid().ToString('N'))
            try {
                $null = New-Item -ItemType Directory -Path $root -Force
                [string]$sourcePath = Join-Path $root 'setup.exe'
                [IO.File]::WriteAllText($sourcePath, 'hash-mismatch-fixture')

                $package = [Package]::new()
                $package.Id = 'Example.HashMismatch'
                $package.Provider = 'EXE'
                $package.InstallerType = 'EXE'

                $request = [PhoenixPackageAcquisitionRequest]::new()
                $request.SetPackage($package)
                [string]$storeRoot = Join-Path $root 'store'
                $request.SetContentStoreRoot($storeRoot)
                $request.Metadata['SourcePath'] = $sourcePath
                $request.Metadata['ExpectedSHA256'] = ('0' * 64)

                $result = Invoke-PhoenixPackageAcquisition -Request $request

                $result.Status | Should-Be ([PhoenixPackageAcquisitionStatus]::Failed)
                $result.Success | Should-BeFalse
                $result.Errors.Count | Should-Be 1
                $result.IsValid() | Should-BeTrue
            }
            finally {
                Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    It 'requires user-supplied media when MSI has no path or URI' {
        InModuleScope Phoenix {
            [string]$root = Join-Path ([IO.Path]::GetTempPath()) ('Phoenix-Acquisition-Test-' + [guid]::NewGuid().ToString('N'))
            try {
                $package = [Package]::new()
                $package.Id = 'Example.MissingMSI'
                $package.Provider = 'MSI'
                $package.InstallerType = 'MSI'

                $request = [PhoenixPackageAcquisitionRequest]::new()
                $request.SetPackage($package)
                [string]$storeRoot = Join-Path $root 'store'
                $request.SetContentStoreRoot($storeRoot)

                $result = Invoke-PhoenixPackageAcquisition -Request $request

                $result.Status | Should-Be ([PhoenixPackageAcquisitionStatus]::UserSuppliedRequired)
                $result.Code | Should-Be 'PHX_PACKAGE_ACQUISITION_MEDIA_REQUIRED'
                $result.IsValid() | Should-BeTrue
            }
            finally {
                Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    It 'requires user-supplied media when EXE has no path or URI' {
        InModuleScope Phoenix {
            [string]$root = Join-Path ([IO.Path]::GetTempPath()) ('Phoenix-Acquisition-Test-' + [guid]::NewGuid().ToString('N'))
            try {
                $package = [Package]::new()
                $package.Id = 'Example.MissingEXE'
                $package.Provider = 'EXE'
                $package.InstallerType = 'EXE'

                $request = [PhoenixPackageAcquisitionRequest]::new()
                $request.SetPackage($package)
                [string]$storeRoot = Join-Path $root 'store'
                $request.SetContentStoreRoot($storeRoot)

                $result = Invoke-PhoenixPackageAcquisition -Request $request

                $result.Status | Should-Be ([PhoenixPackageAcquisitionStatus]::UserSuppliedRequired)
                $result.Success | Should-BeFalse
            }
            finally {
                Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    It 'returns Unsupported when no built-in route matches the provider' {
        InModuleScope Phoenix {
            [string]$root = Join-Path ([IO.Path]::GetTempPath()) ('Phoenix-Acquisition-Test-' + [guid]::NewGuid().ToString('N'))
            try {
                $package = [Package]::new()
                $package.Id = 'Example.Unknown'
                $package.Provider = 'UnknownProvider'
                $package.InstallerType = 'Unknown'

                $request = [PhoenixPackageAcquisitionRequest]::new()
                $request.SetPackage($package)
                [string]$storeRoot = Join-Path $root 'store'
                $request.SetContentStoreRoot($storeRoot)

                $result = Invoke-PhoenixPackageAcquisition -Request $request

                $result.Status | Should-Be ([PhoenixPackageAcquisitionStatus]::Unsupported)
                $result.Code | Should-Be 'PHX_PACKAGE_ACQUISITION_ROUTE_UNAVAILABLE'
                $result.IsValid() | Should-BeTrue
            }
            finally {
                Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    It 'returns Unsupported when the provider installer type is incompatible' {
        InModuleScope Phoenix {
            [string]$root = Join-Path ([IO.Path]::GetTempPath()) ('Phoenix-Acquisition-Test-' + [guid]::NewGuid().ToString('N'))
            try {
                $package = [Package]::new()
                $package.Id = 'Example.BadType'
                $package.Provider = 'MSI'
                $package.InstallerType = 'EXE'

                $request = [PhoenixPackageAcquisitionRequest]::new()
                $request.SetPackage($package)
                [string]$storeRoot = Join-Path $root 'store'
                $request.SetContentStoreRoot($storeRoot)

                $result = Invoke-PhoenixPackageAcquisition -Request $request

                $result.Status | Should-Be ([PhoenixPackageAcquisitionStatus]::Unsupported)
                $result.Success | Should-BeFalse
            }
            finally {
                Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    It 'downloads HTTPS media through the isolated acquisition working directory' {
        InModuleScope Phoenix {
            [string]$root = Join-Path ([IO.Path]::GetTempPath()) ('Phoenix-Acquisition-Test-' + [guid]::NewGuid().ToString('N'))
            try {
                $null = New-Item -ItemType Directory -Path $root -Force
                [string]$fixturePath = Join-Path $root 'fixture.exe'
                [IO.File]::WriteAllText($fixturePath, 'remote-fixture')

                $script:PhoenixAcquisitionRemoteFixture =
                    $fixturePath

                $script:PhoenixAcquisitionInvokeWebRequestCount =
                    0

                Mock Invoke-WebRequest {
                    param(
                        $Uri,
                        $OutFile,
                        $UseBasicParsing,
                        $MaximumRedirection,
                        $TimeoutSec,
                        $ErrorAction
                    )

                    $script:PhoenixAcquisitionInvokeWebRequestCount++

                    Copy-Item `
                        -LiteralPath $script:PhoenixAcquisitionRemoteFixture `
                        -Destination $OutFile `
                        -Force
                }

                $package = [Package]::new()
                $package.Id = 'Example.Remote'
                $package.Provider = 'EXE'
                $package.InstallerType = 'EXE'

                $request = [PhoenixPackageAcquisitionRequest]::new()
                $request.SetPackage($package)
                [string]$storeRoot = Join-Path $root 'store'
                $request.SetContentStoreRoot($storeRoot)
                $request.Metadata['SourceUri'] = 'https://example.invalid/setup.exe'

                $result = Invoke-PhoenixPackageAcquisition -Request $request

                $result.Success | Should-BeTrue
                $result.SourceUri | Should-Be 'https://example.invalid/setup.exe'
                $script:PhoenixAcquisitionInvokeWebRequestCount |
                    Should-Be 1
            }
            finally {
                Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    It 'blocks insecure HTTP unless policy explicitly allows it' {
        InModuleScope Phoenix {
            [string]$root = Join-Path ([IO.Path]::GetTempPath()) ('Phoenix-Acquisition-Test-' + [guid]::NewGuid().ToString('N'))
            try {
                $package = [Package]::new()
                $package.Id = 'Example.Http'
                $package.Provider = 'EXE'
                $package.InstallerType = 'EXE'

                $request = [PhoenixPackageAcquisitionRequest]::new()
                $request.SetPackage($package)
                [string]$storeRoot = Join-Path $root 'store'
                $request.SetContentStoreRoot($storeRoot)
                $request.Metadata['SourceUri'] = 'http://example.invalid/setup.exe'

                $result = Invoke-PhoenixPackageAcquisition -Request $request

                $result.Status | Should-Be ([PhoenixPackageAcquisitionStatus]::Failed)
                ($result.Message -match 'Insecure HTTP') | Should-BeTrue
            }
            finally {
                Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    It 'accepts a file URI as local acquisition media' {
        InModuleScope Phoenix {
            [string]$root = Join-Path ([IO.Path]::GetTempPath()) ('Phoenix-Acquisition-Test-' + [guid]::NewGuid().ToString('N'))
            try {
                $null = New-Item -ItemType Directory -Path $root -Force
                [string]$sourcePath = Join-Path $root 'setup.exe'
                [IO.File]::WriteAllText($sourcePath, 'file-uri-fixture')

                $package = [Package]::new()
                $package.Id = 'Example.FileUri'
                $package.Provider = 'EXE'
                $package.InstallerType = 'EXE'

                $request = [PhoenixPackageAcquisitionRequest]::new()
                $request.SetPackage($package)
                [string]$storeRoot = Join-Path $root 'store'
                $request.SetContentStoreRoot($storeRoot)
                $request.Metadata['SourceUri'] = ([uri]::new($sourcePath)).AbsoluteUri

                $result = Invoke-PhoenixPackageAcquisition -Request $request

                $result.Success | Should-BeTrue
                $result.Metadata['SourceKind'] | Should-Be 'Local'
            }
            finally {
                Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    It 'preserves the isolated working directory when requested' {
        InModuleScope Phoenix {
            [string]$root = Join-Path ([IO.Path]::GetTempPath()) ('Phoenix-Acquisition-Test-' + [guid]::NewGuid().ToString('N'))
            try {
                $null = New-Item -ItemType Directory -Path $root -Force
                [string]$sourcePath = Join-Path $root 'setup.exe'
                [IO.File]::WriteAllText($sourcePath, 'preserve-fixture')

                $package = [Package]::new()
                $package.Id = 'Example.Preserve'
                $package.Provider = 'EXE'
                $package.InstallerType = 'EXE'

                $request = [PhoenixPackageAcquisitionRequest]::new()
                $request.SetPackage($package)
                [string]$storeRoot = Join-Path $root 'store'
                $request.SetContentStoreRoot($storeRoot)
                [string]$workingRoot = Join-Path $root 'working'
                $request.SetWorkingDirectory($workingRoot)
                $request.PreserveWorkingDirectory = $true
                $request.Metadata['SourcePath'] = $sourcePath

                $result = Invoke-PhoenixPackageAcquisition -Request $request
                [string]$workingDirectory = [string]$result.Metadata['WorkingDirectory']

                $result.Success | Should-BeTrue
                (Test-Path -LiteralPath $workingDirectory -PathType Container) | Should-BeTrue
            }
            finally {
                Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    It 'cleans the isolated working directory by default' {
        InModuleScope Phoenix {
            [string]$root = Join-Path ([IO.Path]::GetTempPath()) ('Phoenix-Acquisition-Test-' + [guid]::NewGuid().ToString('N'))
            try {
                $null = New-Item -ItemType Directory -Path $root -Force
                [string]$sourcePath = Join-Path $root 'setup.exe'
                [IO.File]::WriteAllText($sourcePath, 'cleanup-fixture')

                $package = [Package]::new()
                $package.Id = 'Example.Cleanup'
                $package.Provider = 'EXE'
                $package.InstallerType = 'EXE'

                $request = [PhoenixPackageAcquisitionRequest]::new()
                $request.SetPackage($package)
                [string]$storeRoot = Join-Path $root 'store'
                $request.SetContentStoreRoot($storeRoot)
                [string]$workingRoot = Join-Path $root 'working'
                $request.SetWorkingDirectory($workingRoot)
                $request.Metadata['SourcePath'] = $sourcePath

                $result = Invoke-PhoenixPackageAcquisition -Request $request
                [string]$workingDirectory = [string]$result.Metadata['WorkingDirectory']

                $result.Success | Should-BeTrue
                (Test-Path -LiteralPath $workingDirectory) | Should-BeFalse
            }
            finally {
                Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    It 'rejects media with an extension outside the selected adapter contract' {
        InModuleScope Phoenix {
            [string]$root = Join-Path ([IO.Path]::GetTempPath()) ('Phoenix-Acquisition-Test-' + [guid]::NewGuid().ToString('N'))
            try {
                $null = New-Item -ItemType Directory -Path $root -Force
                [string]$sourcePath = Join-Path $root 'setup.txt'
                [IO.File]::WriteAllText($sourcePath, 'wrong-extension')

                $package = [Package]::new()
                $package.Id = 'Example.WrongExtension'
                $package.Provider = 'MSI'
                $package.InstallerType = 'MSI'

                $request = [PhoenixPackageAcquisitionRequest]::new()
                $request.SetPackage($package)
                [string]$storeRoot = Join-Path $root 'store'
                $request.SetContentStoreRoot($storeRoot)
                $request.Metadata['SourcePath'] = $sourcePath

                $result = Invoke-PhoenixPackageAcquisition -Request $request

                $result.Status | Should-Be ([PhoenixPackageAcquisitionStatus]::Failed)
                ($result.Message -match 'allowed MSI package type') | Should-BeTrue
            }
            finally {
                Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }
}
