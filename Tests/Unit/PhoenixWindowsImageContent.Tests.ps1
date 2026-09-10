BeforeAll {
    $root=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
    Import-Module (Join-Path $root 'Phoenix.psd1') -Force 6>$null
}
AfterAll { Remove-Module Phoenix -Force -ErrorAction SilentlyContinue }
Describe 'Offline image content transactions' -Tag @('Unit','WindowsImage','Deployment') {
    BeforeEach {
        Mock -ModuleName Phoenix Get-WindowsImage { param($Index) [pscustomobject]@{ImageIndex=$Index;Architecture=9} }
        Mock -ModuleName Phoenix Assert-PhoenixWindowsImageMount {}
        Mock -ModuleName Phoenix Resolve-PhoenixDismPath { 'C:\fixture\dism.exe' }
        Mock -ModuleName Phoenix Test-PhoenixAdministrator { $true }
        InModuleScope Phoenix {
            $script:PackageApplicable=$true
            $script:PackageInstalled=$false
            Mock Get-WindowsPackage {
                param($Path,$PackagePath,$PackageName)
                if ($PackagePath) {
                    [pscustomobject]@{PackageName=([IO.Path]::GetFileNameWithoutExtension($PackagePath));Applicable=$script:PackageApplicable;PackageState= $(if ($script:PackageInstalled) {'Installed'} else {'NotPresent'})}
                } elseif ($PackageName) {
                    [pscustomobject]@{PackageName=$PackageName;PackageState='Installed'}
                }
            }
        }
        Mock -ModuleName Phoenix Invoke-PhoenixExternalTool { [pscustomobject]@{ExitCode=0;Output=@()} }
        $source=Join-Path $TestDrive ('image-'+[guid]::NewGuid()+'.wim')
        [IO.File]::WriteAllText($source,'image fixture')
        $workspacePath=Join-Path $TestDrive ('workspace-'+[guid]::NewGuid())
        $workspace=New-PhoenixWindowsImageWorkspace -SourceImagePath $source -ImageIndex 1 -Path $workspacePath -Confirm:$false
        InModuleScope Phoenix -Parameters @{W=$workspace} { param($W) $W.SetState('Mounted'); Save-PhoenixWindowsImageWorkspaceMetadata -Workspace $W }
        $inputRoot=Join-Path $TestDrive ('inputs-'+[guid]::NewGuid())
        $null=New-Item -ItemType Directory -Path $inputRoot
        $package=Join-Path $inputRoot 'fixture.cab'
        [IO.File]::WriteAllText($package,'package fixture')
    }
    It 'previews content without staging or invoking DISM' {
        $preview=Add-PhoenixWindowsImageContent -WorkspacePath $workspacePath -Type Package -Value $package -WhatIf
        $preview.Preview | Should-BeTrue
        Test-Path (Join-Path $workspacePath 'servicing') | Should-BeFalse
        Should-NotInvoke -ModuleName Phoenix Invoke-PhoenixExternalTool
    }
    It 'stages and verifies a package, preserving its input and recording success' {
        $hash=(Get-FileHash $package).Hash
        $result=Add-PhoenixWindowsImageContent -WorkspacePath $workspacePath -Type Package -Value $package -Confirm:$false
        $result.Applied | Should-BeTrue
        $result.Verification | Should-Be 'Installed'
        (Get-FileHash $package).Hash | Should-Be $hash
        (Get-Content $result.RecordPath -Raw | ConvertFrom-Json).State | Should-Be 'Verified'
        (Get-PhoenixWindowsImageWorkspace $workspacePath).State | Should-Be 'Mounted'
        Should-Invoke -ModuleName Phoenix Invoke-PhoenixExternalTool -Exactly -Times 1 -ParameterFilter { $ArgumentList -contains '/Add-Package' -and $ArgumentList -contains '/NoRestart' -and $ArgumentList -notcontains '/IgnoreCheck' }
    }
    It 'rejects non-applicable packages without staging' {
        InModuleScope Phoenix { $script:PackageApplicable=$false }
        { Add-PhoenixWindowsImageContent -WorkspacePath $workspacePath -Type Package -Value $package -Confirm:$false } | Should-Throw '*not applicable*'
        Test-Path (Join-Path $workspacePath 'servicing') | Should-BeFalse
        Should-NotInvoke -ModuleName Phoenix Invoke-PhoenixExternalTool
    }
    It 'rejects MSU containers instead of assuming CAB applicability' {
        $msu=Join-Path $inputRoot 'unexamined.msu'
        [IO.File]::WriteAllText($msu,'fixture')
        { Add-PhoenixWindowsImageContent -WorkspacePath $workspacePath -Type Package -Value $msu -Confirm:$false } | Should-Throw '*CAB*'
        Should-NotInvoke -ModuleName Phoenix Invoke-PhoenixExternalTool
    }
    It 'reports already installed content without repeating it' {
        InModuleScope Phoenix { $script:PackageInstalled=$true }
        $result=Add-PhoenixWindowsImageContent -WorkspacePath $workspacePath -Type Package -Value $package,$package -Confirm:$false
        @($result).Count | Should-Be 1
        $result.Reason | Should-Be 'AlreadyInstalled'
        Should-NotInvoke -ModuleName Phoenix Invoke-PhoenixExternalTool
    }
    It 'retains Failed state on DISM error and forbids commit' {
        Mock -ModuleName Phoenix Invoke-PhoenixExternalTool { [pscustomobject]@{ExitCode=5;Output=@()} }
        { Add-PhoenixWindowsImageContent -WorkspacePath $workspacePath -Type Package -Value $package -Confirm:$false } | Should-Throw '*exit code 5*'
        (Get-PhoenixWindowsImageWorkspace $workspacePath).State | Should-Be 'Failed'
        { Dismount-PhoenixWindowsImage -WorkspacePath $workspacePath -Mode Commit -Confirm:$false } | Should-Throw '*Failed transactions*'
    }
    It 'retains Failed state if exit zero lacks installed-state verification' {
        Mock -ModuleName Phoenix Test-PhoenixWindowsImageContentApplied { throw 'Package post-verification failed.' }
        { Add-PhoenixWindowsImageContent -WorkspacePath $workspacePath -Type Package -Value $package -Confirm:$false } | Should-Throw '*post-verification*'
        (Get-PhoenixWindowsImageWorkspace $workspacePath).State | Should-Be 'Failed'
    }
    It 'stops after restart-required status and reports remaining content as not run' {
        $second=Join-Path $inputRoot 'second.cab'
        [IO.File]::WriteAllText($second,'second fixture')
        Mock -ModuleName Phoenix Invoke-PhoenixExternalTool { [pscustomobject]@{ExitCode=3010;Output=@()} }
        $results=@(Add-PhoenixWindowsImageContent -WorkspacePath $workspacePath -Type Package -Value $package,$second -Confirm:$false)
        $results.Count | Should-Be 2
        $results[0].RestartRequired | Should-BeTrue
        $results[1].Reason | Should-Be 'NotRunRestartRequired'
        Should-Invoke -ModuleName Phoenix Invoke-PhoenixExternalTool -Exactly -Times 1
    }
    It 'rejects read-only workspaces' {
        InModuleScope Phoenix -Parameters @{W=$workspace} { param($W) $W.ReadOnly=$true; Save-PhoenixWindowsImageWorkspaceMetadata $W }
        { Add-PhoenixWindowsImageContent -WorkspacePath $workspacePath -Type Package -Value $package -Confirm:$false } | Should-Throw '*writable*'
        Should-NotInvoke -ModuleName Phoenix Invoke-PhoenixExternalTool
    }
    It 'rechecks ownership state under the workspace lock' {
        InModuleScope Phoenix {
            Mock Invoke-PhoenixWindowsImageWorkspaceLock {
                param($WorkspacePath,$Action)
                $owned=Get-PhoenixWindowsImageWorkspaceOwnedInfo $WorkspacePath
                $owned.Workspace.ReadOnly=$true
                Save-PhoenixWindowsImageWorkspaceMetadata $owned.Workspace
                & $Action
            }
        }
        { Add-PhoenixWindowsImageContent -WorkspacePath $workspacePath -Type Package -Value $package -Confirm:$false } | Should-Throw '*state changed*'
        Should-NotInvoke -ModuleName Phoenix Invoke-PhoenixExternalTool
    }
    It 'refuses unsigned driver metadata' {
        $inf=Join-Path $inputRoot 'device.inf'
        [IO.File]::WriteAllText($inf,'driver fixture')
        Mock -ModuleName Phoenix Get-WindowsDriver { [pscustomobject]@{Architecture=9;DriverSignature='Unsigned';BootCritical=$false} }
        { Add-PhoenixWindowsImageContent -WorkspacePath $workspacePath -Type Driver -Value $inf -Confirm:$false } | Should-Throw '*signed x64*'
        Should-NotInvoke -ModuleName Phoenix Invoke-PhoenixExternalTool
    }
    It 'refuses non-x64 driver metadata' {
        $inf=Join-Path $inputRoot 'arm.inf'
        [IO.File]::WriteAllText($inf,'driver fixture')
        Mock -ModuleName Phoenix Get-WindowsDriver { [pscustomobject]@{Architecture=12;DriverSignature='Signed';BootCritical=$false} }
        { Add-PhoenixWindowsImageContent -WorkspacePath $workspacePath -Type Driver -Value $inf -Confirm:$false } | Should-Throw '*signed x64*'
    }
    It 'requires explicit offline capability sources' {
        { Add-PhoenixWindowsImageContent -WorkspacePath $workspacePath -Type Capability -Value 'Test.Capability~~~~0.0.1.0' -Confirm:$false } | Should-Throw '*offline source*'
        Should-NotInvoke -ModuleName Phoenix Invoke-PhoenixExternalTool
    }
    It 'always limits capability access and never forces unsigned drivers' {
        Mock -ModuleName Phoenix Get-WindowsCapability { param($Name) [pscustomobject]@{Name=$Name;State='NotPresent'} }
        Mock -ModuleName Phoenix Test-PhoenixWindowsImageContentApplied { 'Installed' }
        $result=Add-PhoenixWindowsImageContent -WorkspacePath $workspacePath -Type Capability -Value 'Test.Capability~~~~0.0.1.0' -SourcePath $inputRoot -Confirm:$false
        $result.Applied | Should-BeTrue
        Should-Invoke -ModuleName Phoenix Invoke-PhoenixExternalTool -Exactly -Times 1 -ParameterFilter { $ArgumentList -contains '/LimitAccess' -and $ArgumentList -contains '/Add-Capability' -and $ArgumentList -notcontains '/ForceUnsigned' }
    }
    It 'refuses pending package states before any content is staged' {
        Mock -ModuleName Phoenix Get-WindowsPackage { [pscustomobject]@{PackageName='pending';PackageState='InstallPending'} }
        { Add-PhoenixWindowsImageContent -WorkspacePath $workspacePath -Type Package -Value $package -Confirm:$false } | Should-Throw '*Pending packages*'
        Should-NotInvoke -ModuleName Phoenix Invoke-PhoenixExternalTool
    }
    It 'rejects source changes between preview and staging without invoking DISM' {
        InModuleScope Phoenix -Parameters @{Source=$package} {
            param($Source)
            $script:ChangedSource=$Source
            Mock Invoke-PhoenixWindowsImageWorkspaceLock {
                param($WorkspacePath,$Action)
                [IO.File]::AppendAllText($script:ChangedSource,'changed after preview')
                & $Action
            }
        }
        { Add-PhoenixWindowsImageContent -WorkspacePath $workspacePath -Type Package -Value $package -Confirm:$false } | Should-Throw '*source changed*'
        Should-NotInvoke -ModuleName Phoenix Invoke-PhoenixExternalTool
        (Get-PhoenixWindowsImageWorkspace $workspacePath).State | Should-Be 'Mounted'
    }
}
