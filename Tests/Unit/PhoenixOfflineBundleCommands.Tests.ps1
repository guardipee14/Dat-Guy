BeforeAll {
    $projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
    Import-Module (Join-Path $projectRoot 'Phoenix.psd1') -Force 6>$null
}

AfterAll {
    Remove-Module Phoenix -Force -ErrorAction SilentlyContinue
}

Describe 'Phoenix offline-bundle commands' -Tag @('Unit', 'OfflineBundle', 'Command') {
    It 'previews a build without writing anything' {
        $source = Join-Path $TestDrive 'preview.bin'
        [IO.File]::WriteAllText($source, 'preview')
        $bundleRoot = Join-Path $TestDrive 'preview-bundle'

        $manifest = New-PhoenixOfflineBundle -Path $bundleRoot -Name 'Preview' -InputFile $source -WhatIf

        $manifest.ObjectCount | Should-Be 1
        Test-Path -LiteralPath $bundleRoot | Should-BeFalse
    }

    It 'builds, inspects, incrementally updates, verifies, and exports a bundle' {
        $firstSource = Join-Path $TestDrive 'first.bin'
        $secondSource = Join-Path $TestDrive 'second.bin'
        [IO.File]::WriteAllText($firstSource, 'first payload')
        [IO.File]::WriteAllText($secondSource, 'second payload')
        $bundleRoot = Join-Path $TestDrive 'bundle'

        $manifest = New-PhoenixOfflineBundle -Path $bundleRoot -Name 'Recovery' -InputFile $firstSource -Confirm:$false
        $manifest.ObjectCount | Should-Be 1

        $updated = Update-PhoenixOfflineBundle -Path $bundleRoot -InputFile @($firstSource, $secondSource) -Confirm:$false
        $updated.ObjectCount | Should-Be 2

        $summary = Get-PhoenixOfflineBundle -Path $bundleRoot -IncludeManifest
        $summary.Name | Should-Be 'Recovery'
        $summary.ObjectCount | Should-Be 2
        $summary.IntegrityValid | Should-BeTrue
        $summary.Manifest.BundleId | Should-Be $manifest.BundleId

        $exportRoot = Join-Path $TestDrive 'exported'
        Export-PhoenixOfflineBundle -Path $bundleRoot -DestinationPath $exportRoot -Confirm:$false | Should-Be $exportRoot
        (Test-PhoenixOfflineBundle -Path $exportRoot).Success | Should-BeTrue
    }

    It 'removes only a marked Phoenix-owned bundle and honors WhatIf' {
        $bundleRoot = Join-Path $TestDrive 'removable'
        New-PhoenixOfflineBundle -Path $bundleRoot -Name 'Removable' -Confirm:$false | Out-Null

        Remove-PhoenixOfflineBundle -Path $bundleRoot -WhatIf
        Test-Path -LiteralPath $bundleRoot | Should-BeTrue

        Remove-PhoenixOfflineBundle -Path $bundleRoot -Confirm:$false
        Test-Path -LiteralPath $bundleRoot | Should-BeFalse
    }

    It 'rejects cleanup of an unowned directory' {
        $ordinaryDirectory = Join-Path $TestDrive 'ordinary'
        $null = New-Item -ItemType Directory -Path $ordinaryDirectory

        {
            Remove-PhoenixOfflineBundle -Path $ordinaryDirectory -Confirm:$false
        } | Should-Throw

        Test-Path -LiteralPath $ordinaryDirectory | Should-BeTrue
    }
}
