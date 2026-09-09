BeforeAll {
    $projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
    Import-Module (Join-Path $projectRoot 'Phoenix.psd1') -Force 6>$null
}

AfterAll {
    Remove-Module Phoenix -Force -ErrorAction SilentlyContinue
}

Describe 'Phoenix WinPE workspace' -Tag @('Unit', 'WinPE', 'Deployment', 'Safety') {
    BeforeEach {
        $script:mediaRoot = Join-Path $TestDrive 'media-source'
        $script:wimPath = Join-Path $TestDrive 'winpe.wim'
        $null = New-Item -ItemType Directory -Path (Join-Path $script:mediaRoot 'fwfiles') -Force
        $null = New-Item -ItemType Directory -Path (Join-Path $script:mediaRoot 'efi\boot') -Force
        [IO.File]::WriteAllText((Join-Path $script:mediaRoot 'fwfiles\etfsboot.com'), 'bios')
        [IO.File]::WriteAllText((Join-Path $script:mediaRoot 'fwfiles\efisys.bin'), 'uefi')
        [IO.File]::WriteAllText((Join-Path $script:mediaRoot 'efi\boot\bootx64.efi'), 'boot')
        [IO.File]::WriteAllText($script:wimPath, 'winpe fixture')
    }

    It 'previews a workspace without creating it' {
        $workspacePath = Join-Path $TestDrive 'preview-workspace'
        $workspace = New-PhoenixWinPEWorkspace -Path $workspacePath -MediaSourcePath $script:mediaRoot -SourceWimPath $script:wimPath -WhatIf

        $workspace.State | Should-Be 'Staging'
        $workspace.SourceWimSha256 | Should-MatchString '^[0-9a-f]{64}$'
        Test-Path -LiteralPath $workspacePath | Should-BeFalse
    }

    It 'creates an owned workspace while preserving its source inputs' {
        $workspacePath = Join-Path $TestDrive 'workspace'
        $sourceWimHash = (Get-FileHash -LiteralPath $script:wimPath -Algorithm SHA256).Hash
        $sourceMediaHashes = @(
            Get-ChildItem -LiteralPath $script:mediaRoot -File -Recurse |
                Sort-Object FullName |
                ForEach-Object { (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash }
        )

        $workspace = New-PhoenixWinPEWorkspace -Path $workspacePath -MediaSourcePath $script:mediaRoot -SourceWimPath $script:wimPath -Confirm:$false

        $workspace.State | Should-Be 'Ready'
        $workspace.IsValid() | Should-BeTrue
        Test-Path -LiteralPath (Join-Path $workspacePath 'media\sources\boot.wim') | Should-BeTrue
        Test-Path -LiteralPath (Join-Path $workspacePath '.phoenix-winpe-workspace') | Should-BeTrue
        Test-Path -LiteralPath (Join-Path $workspacePath 'workspace.json') | Should-BeTrue
        (Get-FileHash -LiteralPath $script:wimPath -Algorithm SHA256).Hash | Should-Be $sourceWimHash
        @(
            Get-ChildItem -LiteralPath $script:mediaRoot -File -Recurse |
                Sort-Object FullName |
                ForEach-Object { (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash }
        ) | Should-BeCollection $sourceMediaHashes
    }

    It 'removes a partial destination when staging fails' {
        InModuleScope Phoenix -Parameters @{ TestRoot = $TestDrive; SourceMedia = $script:mediaRoot; SourceWim = $script:wimPath } {
            param($TestRoot, $SourceMedia, $SourceWim)

            $workspacePath = Join-Path $TestRoot 'failed-workspace'
            Mock Copy-Item { throw 'simulated staging failure' }

            {
                New-PhoenixWinPEWorkspace -Path $workspacePath -MediaSourcePath $SourceMedia -SourceWimPath $SourceWim -Confirm:$false
            } | Should-Throw

            Test-Path -LiteralPath $workspacePath | Should-BeFalse
        }
    }

    It 'refuses to remove an unowned workspace' {
        $ordinary = Join-Path $TestDrive 'ordinary'
        $null = New-Item -ItemType Directory -Path $ordinary

        { Remove-PhoenixWinPEWorkspace -Path $ordinary -Confirm:$false } | Should-Throw
        Test-Path -LiteralPath $ordinary | Should-BeTrue
    }

    It 'refuses cleanup when ownership and metadata identities differ' {
        $workspacePath = Join-Path $TestDrive 'identity-mismatch'
        New-PhoenixWinPEWorkspace -Path $workspacePath -MediaSourcePath $script:mediaRoot -SourceWimPath $script:wimPath -Confirm:$false | Out-Null
        $markerPath = Join-Path $workspacePath '.phoenix-winpe-workspace'
        $marker = Get-Content -LiteralPath $markerPath -Raw | ConvertFrom-Json
        $marker.WorkspaceId = [guid]::NewGuid().ToString()
        $marker | ConvertTo-Json | Set-Content -LiteralPath $markerPath -Encoding utf8

        { Remove-PhoenixWinPEWorkspace -Path $workspacePath -Confirm:$false } | Should-Throw
        Test-Path -LiteralPath $workspacePath | Should-BeTrue
    }

    It 'removes only an exact owned ready workspace' {
        $workspacePath = Join-Path $TestDrive 'removable-workspace'
        New-PhoenixWinPEWorkspace -Path $workspacePath -MediaSourcePath $script:mediaRoot -SourceWimPath $script:wimPath -Confirm:$false | Out-Null

        Remove-PhoenixWinPEWorkspace -Path $workspacePath -Confirm:$false

        Test-Path -LiteralPath $workspacePath | Should-BeFalse
    }
}
