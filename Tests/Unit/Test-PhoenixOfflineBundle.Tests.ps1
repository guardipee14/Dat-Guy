BeforeAll {
    $projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
    Import-Module (Join-Path $projectRoot 'Phoenix.psd1') -Force 6>$null
}

AfterAll {
    Remove-Module Phoenix -Force -ErrorAction SilentlyContinue
}

Describe 'Test-PhoenixOfflineBundle' -Tag @('Unit', 'OfflineBundle', 'Integrity', 'Trust') {
    It 'verifies a sealed content object and reports missing optional provenance' {
        InModuleScope Phoenix -Parameters @{ TestRoot = $TestDrive } {
            param([string]$TestRoot)

            $bundleRoot = Join-Path $TestRoot 'bundle'
            $source = Join-Path $TestRoot 'payload.bin'
            [IO.File]::WriteAllText($source, 'verified payload')

            $contentObject = Add-PhoenixContentStoreObject -StoreRoot $bundleRoot -LiteralPath $source -Confirm:$false
            $manifest = [PhoenixOfflineBundleManifest]::new()
            $manifest.Name = 'Test bundle'
            $manifest.AddObject($contentObject)
            Save-PhoenixOfflineBundleManifest -Manifest $manifest -LiteralPath (Join-Path $bundleRoot 'manifest.json') -Confirm:$false

            $result = Test-PhoenixOfflineBundle -Path $bundleRoot

            $result.Success | Should-BeTrue
            $result.IntegrityValid | Should-BeTrue
            $result.CheckedObjectCount | Should-Be 1
            $result.Warnings.Count | Should-Be 1
            $result.IsValid() | Should-BeTrue
        }
    }

    It 'detects payload tampering' {
        InModuleScope Phoenix -Parameters @{ TestRoot = $TestDrive } {
            param([string]$TestRoot)

            $bundleRoot = Join-Path $TestRoot 'tampered'
            $source = Join-Path $TestRoot 'payload.bin'
            [IO.File]::WriteAllText($source, 'original')

            $contentObject = Add-PhoenixContentStoreObject -StoreRoot $bundleRoot -LiteralPath $source -Confirm:$false
            $manifest = [PhoenixOfflineBundleManifest]::new()
            $manifest.AddObject($contentObject)
            Save-PhoenixOfflineBundleManifest -Manifest $manifest -LiteralPath (Join-Path $bundleRoot 'manifest.json') -Confirm:$false

            $objectPath = Resolve-PhoenixContentStoreObjectPath -StoreRoot $bundleRoot -Address ([PhoenixContentAddress]::new($contentObject.Digest))
            [IO.File]::WriteAllText($objectPath, 'tampered')

            $result = Test-PhoenixOfflineBundle -Path $bundleRoot

            $result.Success | Should-BeFalse
            $result.IntegrityValid | Should-BeFalse
            $result.Errors.Count | Should-Be 1
        }
    }

    It 'enforces provenance, redistributable license, and trusted publisher policy' {
        InModuleScope Phoenix -Parameters @{ TestRoot = $TestDrive } {
            param([string]$TestRoot)

            $bundleRoot = Join-Path $TestRoot 'trusted'
            $source = Join-Path $TestRoot 'setup.exe'
            [IO.File]::WriteAllText($source, 'signed fixture')

            $contentObject = Add-PhoenixContentStoreObject -StoreRoot $bundleRoot -LiteralPath $source -Confirm:$false
            $manifest = [PhoenixOfflineBundleManifest]::new()
            $manifest.AddObject($contentObject)
            $manifest.Packages = @([pscustomobject]@{ PackageId = 'Contoso.App' })
            $manifest.Licenses = @([pscustomobject]@{ PackageId = 'Contoso.App'; Expression = 'MIT'; Redistributable = $true })
            $manifest.Provenance = @([pscustomobject]@{ ObjectId = $contentObject.ObjectId; Source = 'https://example.invalid/setup.exe'; SignatureStatus = 'Valid'; Publisher = 'CN=Contoso' })
            Save-PhoenixOfflineBundleManifest -Manifest $manifest -LiteralPath (Join-Path $bundleRoot 'manifest.json') -Confirm:$false

            $result = Test-PhoenixOfflineBundle -Path $bundleRoot -Policy TrustedPublisher

            $result.Success | Should-BeTrue
            $result.ProvenanceValid | Should-BeTrue
            $result.LicenseValid | Should-BeTrue
            $result.TrustValid | Should-BeTrue
        }
    }

    It 'fails closed when strict provenance is absent' {
        InModuleScope Phoenix -Parameters @{ TestRoot = $TestDrive } {
            param([string]$TestRoot)

            $bundleRoot = Join-Path $TestRoot 'missing-provenance'
            $source = Join-Path $TestRoot 'payload.bin'
            [IO.File]::WriteAllText($source, 'payload')

            $contentObject = Add-PhoenixContentStoreObject -StoreRoot $bundleRoot -LiteralPath $source -Confirm:$false
            $manifest = [PhoenixOfflineBundleManifest]::new()
            $manifest.AddObject($contentObject)
            Save-PhoenixOfflineBundleManifest -Manifest $manifest -LiteralPath (Join-Path $bundleRoot 'manifest.json') -Confirm:$false

            $result = Test-PhoenixOfflineBundle -Path $bundleRoot -Policy ProvenanceRequired

            $result.Success | Should-BeFalse
            $result.ProvenanceValid | Should-BeFalse
            $result.Errors.Count | Should-Be 1
        }
    }
}
