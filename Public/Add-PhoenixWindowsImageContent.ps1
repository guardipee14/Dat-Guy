using module '..\Classes\Phoenix.Classes.psm1'

function Add-PhoenixWindowsImageContent {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact='High')]
    [OutputType([pscustomobject[]])]
    param(
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$WorkspacePath,
        [Parameter(Mandatory)][ValidateSet('Driver','Package','Capability')][string]$Type,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string[]]$Value,
        [string]$SourcePath='',
        [string]$DismPath=''
    )
    $info=Get-PhoenixWindowsImageWorkspaceOwnedInfo -Path $WorkspacePath
    if ($info.Workspace.State -ne 'Mounted' -or $info.Workspace.ReadOnly) { throw 'Servicing requires a mounted writable Phoenix-owned workspace.' }
    if (-not (Test-PhoenixAdministrator)) { throw 'Administrator privileges are required for image servicing.' }
    $dism=Resolve-PhoenixDismPath -Path $DismPath
    Assert-PhoenixWindowsImageMount -Workspace $info.Workspace
    $plans=@(foreach ($entry in $Value | Select-Object -Unique) {
        $plan=Get-PhoenixWindowsImageContentPlan -Workspace $info.Workspace -Type $Type -Value $entry -SourcePath $SourcePath
        foreach ($file in $plan.Files) {
            if ($file.Path.StartsWith($info.RootPath.TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase)) {
                throw 'Servicing inputs must be outside the workspace to avoid recursive or mutable sources.'
            }
        }
        $plan
    })
    if (-not $PSCmdlet.ShouldProcess($info.Workspace.MountPath, "Stage, add and verify $Type inputs: $($plans.Identity -join ', ')")) {
        return @($plans | Select-Object Type,Value,Identity,AlreadyInstalled,BootCritical,Bytes,@{n='Preview';e={$true}})
    }
    return Invoke-PhoenixWindowsImageWorkspaceLock -WorkspacePath $info.RootPath -Action {
        $info=Get-PhoenixWindowsImageWorkspaceOwnedInfo -Path $WorkspacePath
        if ($info.Workspace.State -ne 'Mounted' -or $info.Workspace.ReadOnly) { throw 'Workspace state changed before servicing.' }
        Assert-PhoenixWindowsImageMount -Workspace $info.Workspace
        $results=[Collections.Generic.List[object]]::new()
        foreach ($plan in $plans) {
            if ($plan.AlreadyInstalled) {
                $results.Add([pscustomobject]@{Type=$Type;Value=$plan.Value;Identity=$plan.Identity;Applied=$false;Skipped=$true;Reason='AlreadyInstalled';Preview=$false})
                continue
            }
            $stage=Join-Path $info.RootPath ('servicing\'+[guid]::NewGuid().ToString('N'))
            Test-PhoenixPathAncestors -Path $stage
            $drive=[IO.DriveInfo]::new([IO.Path]::GetPathRoot($stage))
            if ($drive.AvailableFreeSpace -lt ($plan.Bytes+1GB)) { throw 'Insufficient free space for servicing staging and scratch.' }
            $null=New-Item -ItemType Directory -Path (Join-Path $stage 'payload') -ErrorAction Stop
            foreach ($file in $plan.Files) {
                Test-PhoenixPathAncestors -Path $file.Path
                if ((Get-FileHash -LiteralPath $file.Path -Algorithm SHA256).Hash -ine $file.SHA256) { throw 'Servicing source changed since preview.' }
                $destination=Join-Path (Join-Path $stage 'payload') $file.RelativePath
                $null=New-Item -ItemType Directory -Path (Split-Path $destination -Parent) -Force -ErrorAction Stop
                Copy-Item -LiteralPath $file.Path -Destination $destination -ErrorAction Stop
                if ((Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash -ine $file.SHA256) { throw 'Staged servicing input hash mismatch.' }
            }
            $stagedValue=if ($Type -eq 'Capability') { $plan.Value } else { Join-Path (Join-Path $stage 'payload') ([IO.Path]::GetFileName($plan.Value)) }
            $stagedSource=if ($Type -eq 'Capability') { Join-Path $stage 'payload' } else { '' }
            $stagedPlan=Get-PhoenixWindowsImageContentPlan -Workspace $info.Workspace -Type $Type -Value $stagedValue -SourcePath $stagedSource
            if ($stagedPlan.Identity -cne $plan.Identity) { throw 'Staged input identity differs from the reviewed input.' }
            $record=[pscustomobject]@{
                Schema='PhoenixImageServicingOperation';SchemaVersion='1.0';OperationId=[guid]::NewGuid().ToString()
                WorkspaceId=$info.Workspace.WorkspaceId;Type=$Type;Identity=$plan.Identity;SourceFiles=$plan.Files
                StartedAtUtc=[datetime]::UtcNow;State='Running';ExitCode=$null;RestartRequired=$false;Verification=''
            }
            $recordPath=Join-Path $stage 'operation.json'
            $record | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $recordPath -Encoding utf8 -ErrorAction Stop
            $info.Workspace.SetState('Failed')
            $info.Workspace.AddOperation("Servicing intent: $Type $($plan.Identity), operation $($record.OperationId).")
            Save-PhoenixWindowsImageWorkspaceMetadata -Workspace $info.Workspace
            try {
                Assert-PhoenixWindowsImageMount -Workspace $info.Workspace
                $arguments=@('/English',"/Image:$($info.Workspace.MountPath)",'/NoRestart',"/LogPath:$(Join-Path $stage 'dism.log')")
                switch ($Type) {
                    'Package' { $arguments+=@('/Add-Package',"/PackagePath:$stagedValue") }
                    'Driver' { $arguments+=@('/Add-Driver',"/Driver:$stagedValue") }
                    'Capability' { $arguments+=@('/Add-Capability',"/CapabilityName:$stagedValue","/Source:$stagedSource",'/LimitAccess') }
                }
                $result=Invoke-PhoenixExternalTool -FilePath $dism -ArgumentList $arguments
                $record.ExitCode=$result.ExitCode
                if ($result.ExitCode -notin @(0,3010)) { throw "DISM servicing failed with exit code $($result.ExitCode)." }
                $record.Verification=Test-PhoenixWindowsImageContentApplied -Workspace $info.Workspace -Plan $stagedPlan
                $record.RestartRequired=$result.ExitCode -eq 3010 -or $record.Verification -eq 'InstallPending'
                $record.State='Verified'
                $record | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $recordPath -Encoding utf8 -ErrorAction Stop
                $info.Workspace.SetState('Mounted')
                $info.Workspace.AddOperation("Verified $Type $($plan.Identity). Restart required: $($record.RestartRequired).")
                Save-PhoenixWindowsImageWorkspaceMetadata -Workspace $info.Workspace
                $results.Add([pscustomobject]@{Type=$Type;Value=$plan.Value;Identity=$plan.Identity;Applied=$true;Skipped=$false;Preview=$false;BootCritical=$plan.BootCritical;RestartRequired=$record.RestartRequired;Verification=$record.Verification;RecordPath=$recordPath})
                if ($record.RestartRequired) {
                    $remaining=$false
                    foreach ($nextPlan in $plans) {
                        if ($remaining) { $results.Add([pscustomobject]@{Type=$Type;Value=$nextPlan.Value;Identity=$nextPlan.Identity;Applied=$false;Skipped=$true;Reason='NotRunRestartRequired';Preview=$false}) }
                        if ([object]::ReferenceEquals($nextPlan,$plan)) { $remaining=$true }
                    }
                    break
                }
            }
            catch {
                $record.State='Failed'
                $record | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $recordPath -Encoding utf8 -ErrorAction Stop
                throw
            }
        }
        return @($results)
    }
}
