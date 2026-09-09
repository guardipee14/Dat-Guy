BeforeAll {
    $root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
    Import-Module (Join-Path $root 'Phoenix.psd1') -Force 6>$null
}
AfterAll { Remove-Module Phoenix -Force -ErrorAction SilentlyContinue }

Describe 'Boot media integrity and destructive boundary' {
    BeforeEach {
        $fixture = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $media = Join-Path $fixture 'source'
        $null = New-Item -ItemType Directory -Path (Join-Path $media 'efi\boot') -Force
        $null = New-Item -ItemType Directory -Path (Join-Path $media 'fwfiles') -Force
        foreach ($file in @('efi\boot\bootx64.efi','fwfiles\efisys.bin','fwfiles\etfsboot.com')) {
            [IO.File]::WriteAllText((Join-Path $media $file), 'boot fixture')
        }
        $wim = Join-Path $fixture 'source.wim'
        [IO.File]::WriteAllText($wim, 'wim fixture')
        $workspace = New-PhoenixWinPEWorkspace -Path (Join-Path $fixture 'workspace') -MediaSourcePath $media -SourceWimPath $wim -Confirm:$false
        $tool = Join-Path $fixture 'oscdimg.exe'
        [IO.File]::WriteAllText($tool, 'tool fixture')
        $isoArgs = @{ WorkspacePath=$workspace.RootPath; OscdimgPath=$tool; OutputPath=(Join-Path $fixture 'output.iso') }
        $mediaArgs = @{ WorkspacePath=$workspace.RootPath; DiskNumber=91; DiskUniqueId='USB-TEST'; DiskSerialNumber='SERIAL-TEST'; DiskSize=8GB; BusType='USB'; ConfirmationText='ERASE DISK 91 USB-TEST SERIAL-TEST' }
        Mock Test-PhoenixAdministrator -ModuleName Phoenix { $true }
        Mock Get-Disk -ModuleName Phoenix { [pscustomobject]@{Number=91;UniqueId='USB-TEST';SerialNumber='SERIAL-TEST';Size=8GB;BusType='USB';IsBoot=$false;IsSystem=$false;IsOffline=$false;IsReadOnly=$false} }
        Mock Get-Partition -ModuleName Phoenix { [pscustomobject]@{DiskNumber=0;PartitionNumber=3} }
        Mock Clear-Disk -ModuleName Phoenix { throw 'Test guard: real disk erasure must never execute.' }
        Mock Invoke-PhoenixExternalTool -ModuleName Phoenix { throw 'Test guard: external tool must not execute.' }
    }
    It 'previews ISO creation without invoking tools or writing output' {
        (New-PhoenixBootableIso @isoArgs -WhatIf).Created | Should-BeFalse
        Test-Path -LiteralPath $isoArgs.OutputPath | Should-BeFalse
        Should-NotInvoke Invoke-PhoenixExternalTool -ModuleName Phoenix
    }
    It 'rejects ISO output inside input media' {
        $isoArgs.OutputPath=Join-Path $workspace.MediaPath 'output.iso'
        { New-PhoenixBootableIso @isoArgs -Confirm:$false } | Should-Throw
        Should-NotInvoke Invoke-PhoenixExternalTool -ModuleName Phoenix
    }
    It 'removes a partial ISO after tool failure' {
        Mock Invoke-PhoenixExternalTool -ModuleName Phoenix { [pscustomobject]@{ExitCode=1;Output=@('simulated failure')} }
        { New-PhoenixBootableIso @isoArgs -Confirm:$false } | Should-Throw
        Test-Path -LiteralPath $isoArgs.OutputPath | Should-BeFalse
    }
    It 'uses the ADK tool directory when boot sectors are absent from Media' {
        Remove-Item -LiteralPath (Join-Path $workspace.MediaPath 'fwfiles\etfsboot.com'),(Join-Path $workspace.MediaPath 'fwfiles\efisys.bin')
        foreach ($name in @('etfsboot.com','efisys.bin')) { [IO.File]::WriteAllText((Join-Path $fixture $name),'ADK fixture') }
        (New-PhoenixBootableIso @isoArgs -WhatIf).Created | Should-BeFalse
    }
    It 'refuses media metadata redirected outside the owned root' {
        $metadataPath=Join-Path $workspace.RootPath 'workspace.json'
        $metadata=Get-Content -LiteralPath $metadataPath -Raw | ConvertFrom-Json
        $metadata.MediaPath=$media
        $metadata | ConvertTo-Json | Set-Content -LiteralPath $metadataPath
        { New-PhoenixBootableIso @isoArgs -WhatIf } | Should-Throw
    }
    It 'previews capacity and identity without erasing' {
        $preview=Copy-PhoenixBootableMedia @mediaArgs -WhatIf
        $preview.Preview | Should-BeTrue
        $preview.RequiredBytes | Should-BeGreaterThan 64MB
        Should-NotInvoke Clear-Disk -ModuleName Phoenix
    }
    It 'refuses a boot or system disk' {
        Mock Get-Disk -ModuleName Phoenix { [pscustomobject]@{Number=91;IsBoot=$true;IsSystem=$true;IsReadOnly=$false;IsOffline=$false} }
        { Copy-PhoenixBootableMedia @mediaArgs -Confirm:$false } | Should-Throw
        Should-NotInvoke Clear-Disk -ModuleName Phoenix
    }
    It 'requires administrator privileges' {
        Mock Test-PhoenixAdministrator -ModuleName Phoenix { $false }
        { Copy-PhoenixBootableMedia @mediaArgs -Confirm:$false } | Should-Throw
        Should-NotInvoke Clear-Disk -ModuleName Phoenix
    }
    It 'refuses mismatched serial numbers' {
        $mediaArgs.DiskSerialNumber='OTHER'
        { Copy-PhoenixBootableMedia @mediaArgs -Confirm:$false } | Should-Throw
        Should-NotInvoke Clear-Disk -ModuleName Phoenix
    }
    It 'requires exact typed confirmation' {
        $mediaArgs.ConfirmationText='yes'
        { Copy-PhoenixBootableMedia @mediaArgs -Confirm:$false } | Should-Throw
        Should-NotInvoke Clear-Disk -ModuleName Phoenix
    }
    It 'refuses erasing a disk containing the source workspace' {
        Mock Get-Partition -ModuleName Phoenix { [pscustomobject]@{DiskNumber=91} }
        { Copy-PhoenixBootableMedia @mediaArgs -Confirm:$false } | Should-Throw
        Should-NotInvoke Clear-Disk -ModuleName Phoenix
    }
    It 'rejects oversized FAT32 payloads before erasure' {
        Mock Get-PhoenixBootMediaInventory -ModuleName Phoenix { [pscustomobject]@{Length=5GB;RelativePath='sources\boot.wim';Sha256='test'} }
        { Copy-PhoenixBootableMedia @mediaArgs -Confirm:$false } | Should-Throw
        Should-NotInvoke Clear-Disk -ModuleName Phoenix
    }
    It 'rejects insufficient aggregate capacity before erasure' {
        Mock Get-PhoenixBootMediaInventory -ModuleName Phoenix { 1..4 | ForEach-Object { [pscustomobject]@{Length=3GB;RelativePath="$_";Sha256='test'} } }
        { Copy-PhoenixBootableMedia @mediaArgs -Confirm:$false } | Should-Throw
        Should-NotInvoke Clear-Disk -ModuleName Phoenix
    }
    It 'rechecks identity immediately before the destructive call' {
        InModuleScope Phoenix { $script:BootMediaTestReads=0 }
        Mock Get-Disk -ModuleName Phoenix {
            $script:BootMediaTestReads++
            $id = if ($script:BootMediaTestReads -eq 1) {'USB-TEST'} else {'CHANGED'}
            [pscustomobject]@{Number=91;UniqueId=$id;SerialNumber='SERIAL-TEST';Size=8GB;BusType='USB';IsBoot=$false;IsSystem=$false;IsOffline=$false;IsReadOnly=$false}
        }
        { Copy-PhoenixBootableMedia @mediaArgs -Confirm:$false } | Should-Throw
        Should-NotInvoke Clear-Disk -ModuleName Phoenix
    }
}
