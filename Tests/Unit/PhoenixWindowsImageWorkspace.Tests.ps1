BeforeAll {
    $projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
    Import-Module (Join-Path $projectRoot 'Phoenix.psd1') -Force 6>$null
}
AfterAll { Remove-Module Phoenix -Force -ErrorAction SilentlyContinue }

Describe 'Phoenix Windows-image transactions' -Tag @('Unit', 'Deployment', 'WindowsImage', 'DISM') {
    BeforeEach {
        InModuleScope Phoenix { $script:ImageTestMounts = @() }
        Mock -ModuleName Phoenix Get-WindowsImage {
            param($ImagePath, $Index)
            [pscustomobject]@{ ImageIndex = $Index; Architecture = 9 }
        }
        InModuleScope Phoenix {
            Mock Get-WindowsImage { foreach ($record in $script:ImageTestMounts) { $record } } -ParameterFilter { $Mounted }
        }
        Mock -ModuleName Phoenix Test-PhoenixAdministrator { $true }
        Mock -ModuleName Phoenix Resolve-PhoenixDismPath { 'C:\fixture\dism.exe' }
        Mock -ModuleName Phoenix Invoke-PhoenixExternalTool { throw 'Unplanned DISM invocation.' }
        $source = Join-Path $TestDrive ('source-' + [guid]::NewGuid() + '.wim')
        [IO.File]::WriteAllText($source, 'source fixture')
        $workspacePath = Join-Path $TestDrive ('workspace-' + [guid]::NewGuid())
        $workspace = New-PhoenixWindowsImageWorkspace -SourceImagePath $source -Path $workspacePath -ImageIndex 2 -Confirm:$false
    }

    It 'preserves the source and selected WIM index' {
        $workspace.IsValid() | Should-BeTrue
        $workspace.ImageIndex | Should-Be 2
        $workspace.SourceImageIndex | Should-Be 2
        $workspace.State | Should-Be 'Ready'
        (Get-FileHash $source).Hash | Should-Be (Get-FileHash $workspace.WorkingImagePath).Hash
    }
    It 'rejects an existing destination without deleting it' {
        { New-PhoenixWindowsImageWorkspace -SourceImagePath $source -Path $workspacePath -ImageIndex 2 -Confirm:$false } | Should-Throw '*already exists*'
        Test-Path $workspace.WorkingImagePath | Should-BeTrue
    }
    It 'rejects unsupported image architectures before staging' {
        Mock -ModuleName Phoenix Get-WindowsImage { [pscustomobject]@{ ImageIndex = 2; Architecture = 12 } }
        $destination = Join-Path $TestDrive 'arm-image'
        { New-PhoenixWindowsImageWorkspace -SourceImagePath $source -Path $destination -ImageIndex 2 -Confirm:$false } | Should-Throw '*x64*'
        Test-Path $destination | Should-BeFalse
    }
    It 'exports ESD index explicitly into WIM index one' {
        $esd = Join-Path $TestDrive 'source.esd'
        [IO.File]::WriteAllText($esd, 'esd fixture')
        Mock -ModuleName Phoenix Invoke-PhoenixExternalTool {
            param($FilePath, $ArgumentList)
            $output = ($ArgumentList | Where-Object { $_ -like '/DestinationImageFile:*' }).Substring(22)
            [IO.File]::WriteAllText($output, 'exported WIM fixture')
            [pscustomobject]@{ ExitCode = 0; Output = @() }
        }
        $exported = New-PhoenixWindowsImageWorkspace -SourceImagePath $esd -Path (Join-Path $TestDrive 'esd-workspace') -ImageIndex 2 -Confirm:$false
        $exported.ImageIndex | Should-Be 1
        $exported.SourceImageIndex | Should-Be 2
        $exported.WorkingImagePath | Should-MatchString '\.wim$'
        [IO.File]::ReadAllText($esd) | Should-Be 'esd fixture'
        Should-Invoke -ModuleName Phoenix Invoke-PhoenixExternalTool -Times 1 -Exactly -ParameterFilter { $ArgumentList -contains '/Export-Image' -and $ArgumentList -contains '/SourceIndex:2' }
    }
    It 'previews mounting without calling DISM or changing metadata' {
        $before = (Get-FileHash (Join-Path $workspacePath 'workspace.json')).Hash
        (Mount-PhoenixWindowsImage -WorkspacePath $workspacePath -WhatIf).State | Should-Be 'Ready'
        (Get-FileHash (Join-Path $workspacePath 'workspace.json')).Hash | Should-Be $before
        Should-NotInvoke -ModuleName Phoenix Invoke-PhoenixExternalTool
    }
    It 'rejects changed image content before mounting' {
        [IO.File]::AppendAllText($workspace.WorkingImagePath, 'changed')
        { Mount-PhoenixWindowsImage -WorkspacePath $workspacePath -Confirm:$false } | Should-Throw '*hash changed*'
        Should-NotInvoke -ModuleName Phoenix Invoke-PhoenixExternalTool
    }
    It 'rejects a missing administrator token' {
        Mock -ModuleName Phoenix Test-PhoenixAdministrator { $false }
        { Mount-PhoenixWindowsImage -WorkspacePath $workspacePath -Confirm:$false } | Should-Throw '*Administrator*'
        Should-NotInvoke -ModuleName Phoenix Invoke-PhoenixExternalTool
    }
    It 'retains Failed state after DISM failure' {
        Mock -ModuleName Phoenix Invoke-PhoenixExternalTool { [pscustomobject]@{ ExitCode = 5; Output = @('failure') } }
        { Mount-PhoenixWindowsImage -WorkspacePath $workspacePath -Confirm:$false } | Should-Throw '*DISM mount failed*'
        (Get-PhoenixWindowsImageWorkspace -Path $workspacePath).State | Should-Be 'Failed'
        Test-Path $workspace.WorkingImagePath | Should-BeTrue
    }
    It 'does not infer mount success solely from exit zero' {
        Mock -ModuleName Phoenix Invoke-PhoenixExternalTool { [pscustomobject]@{ ExitCode = 0; Output = @() } }
        { Mount-PhoenixWindowsImage -WorkspacePath $workspacePath -Confirm:$false } | Should-Throw '*matching Windows mount*'
        (Get-PhoenixWindowsImageWorkspace -Path $workspacePath).State | Should-Be 'Failed'
    }
    It 'blocks cleanup when the Windows mount registry references an apparently Ready workspace' {
        InModuleScope Phoenix -Parameters @{ W = $workspace } {
            param($W)
            $script:ImageTestMounts = @([pscustomobject]@{ Path=$W.MountPath; ImagePath=$W.WorkingImagePath; ImageIndex=2; MountMode='ReadWrite'; MountStatus='Ok' })
        }
        { Remove-PhoenixWindowsImageWorkspace -Path $workspacePath -Confirm:$false } | Should-Throw '*live or abandoned*'
        Test-Path $workspace.WorkingImagePath | Should-BeTrue
    }
    It 'rejects tampered owned paths before cleanup' {
        $metadataPath = Join-Path $workspacePath 'workspace.json'
        $raw = Get-Content $metadataPath -Raw | ConvertFrom-Json
        $raw.MountPath = $TestDrive
        $raw | ConvertTo-Json | Set-Content $metadataPath
        { Remove-PhoenixWindowsImageWorkspace -Path $workspacePath -Confirm:$false } | Should-Throw '*exact owned children*'
        Test-Path $source | Should-BeTrue
    }
    It 'does not release another operation lock or mislabel action IO errors' {
        InModuleScope Phoenix -Parameters @{ Root=$workspacePath } {
            param($Root)
            $lock = Join-Path $Root '.phoenix-image.lock'
            $handle = [IO.File]::Open($lock, 'OpenOrCreate', 'ReadWrite', 'None')
            try {
                { Invoke-PhoenixWindowsImageWorkspaceLock -WorkspacePath $Root -Action { throw 'unexpected' } } | Should-Throw '*Another Phoenix*'
                Test-Path $lock | Should-BeTrue
            } finally { $handle.Dispose() }
            { Invoke-PhoenixWindowsImageWorkspaceLock -WorkspacePath $Root -Action { throw [IO.IOException]::new('actual IO failure') } } | Should-Throw '*actual IO failure*'
        }
    }
    It 'rejects mismatched mount identity for dismount: <Field>' -ForEach @(
        @{Field='ImagePath';Value='C:\foreign.wim'},
        @{Field='ImageIndex';Value=3},
        @{Field='MountMode';Value='ReadOnly'},
        @{Field='MountStatus';Value='NeedsRemount'}
    ) {
        InModuleScope Phoenix -Parameters @{ W=$workspace; Field=$Field; Value=$Value } {
            param($W,$Field,$Value)
            $W.SetState('Mounted')
            Save-PhoenixWindowsImageWorkspaceMetadata -Workspace $W
            $record = [pscustomobject]@{ Path=$W.MountPath; ImagePath=$W.WorkingImagePath; ImageIndex=2; MountMode='ReadWrite'; MountStatus='Ok' }
            $record.$Field = $Value
            $script:ImageTestMounts = @($record)
        }
        { Dismount-PhoenixWindowsImage -WorkspacePath $workspacePath -Mode Discard -Confirm:$false } | Should-Throw '*differs*'
        Should-NotInvoke -ModuleName Phoenix Invoke-PhoenixExternalTool
    }
    It 'verifies a mount and discard round trip against live records' {
        InModuleScope Phoenix {
        Mock Invoke-PhoenixExternalTool {
            param($FilePath, $ArgumentList)
            if ($ArgumentList -contains '/Mount-Image') {
                $script:ImageTestMounts = @([pscustomobject]@{
                    Path=($ArgumentList | Where-Object { $_ -like '/MountDir:*' }).Substring(10)
                    ImagePath=($ArgumentList | Where-Object { $_ -like '/ImageFile:*' }).Substring(11)
                    ImageIndex=2; MountMode='ReadOnly'; MountStatus='Ok'
                })
            } else { $script:ImageTestMounts = @() }
            [pscustomobject]@{ ExitCode=0; Output=@() }
        }
        }
        (Mount-PhoenixWindowsImage -WorkspacePath $workspacePath -ReadOnly -Confirm:$false).State | Should-Be 'Mounted'
        { Dismount-PhoenixWindowsImage -WorkspacePath $workspacePath -Mode Commit -Confirm:$false } | Should-Throw '*read-only*'
        (Dismount-PhoenixWindowsImage -WorkspacePath $workspacePath -Mode Discard -Confirm:$false).State | Should-Be 'Ready'
        Should-Invoke -ModuleName Phoenix Invoke-PhoenixExternalTool -Exactly -Times 2
    }
    It 'removes only an unmounted owned workspace, preserving the source' {
        Remove-PhoenixWindowsImageWorkspace -Path $workspacePath -Confirm:$false
        Test-Path $workspacePath | Should-BeFalse
        Test-Path $source | Should-BeTrue
    }
    It 'rejects unowned cleanup' {
        { Remove-PhoenixWindowsImageWorkspace -Path $TestDrive -Confirm:$false } | Should-Throw '*not marked*'
        Test-Path $source | Should-BeTrue
    }
}
