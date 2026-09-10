using module '..\Classes\Phoenix.Classes.psm1'

function Show-PhoenixDiskPlan {

    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [PhoenixDiskPlan]$Plan,

        [Parameter()]
        [ValidateRange(1, 30)]
        [int]$PreviewLifetimeMinutes = 10
    )

    process {
        if ($null -eq $Plan -or -not $Plan.IsValid()) {
            throw 'A valid Phoenix disk plan is required.'
        }

        $Plan.SetPreview($PreviewLifetimeMinutes)

        return [pscustomobject]@{
            Plan = $Plan
            PlanId = $Plan.PlanId
            DiskNumber = $Plan.Target.DiskNumber
            DiskIdentity = $Plan.Target.Fingerprint
            DiskSize = $Plan.Target.Size
            UniqueId = $Plan.Target.UniqueId
            SerialNumber = $Plan.Target.SerialNumber
            BusType = $Plan.Target.BusType
            RequiredBytes = $Plan.RequiredBytes
            UnallocatedBytes = $Plan.UnallocatedBytes
            GptTailReserveBytes = 1MB
            ExecutionEnabled = $false
            ValidationScope = 'ReadOnlyPlan; live identity must be rechecked before any future execution'
            PreviewToken = $Plan.PreviewToken
            PreviewDigest = $Plan.PreviewDigest
            PreviewExpiresAtUtc = $Plan.PreviewExpiresAtUtc
            Partitions = @($Plan.Partitions | ForEach-Object {
                [pscustomobject]@{
                    Name = $_.Name
                    Role = $_.Role
                    Offset = $_.Offset
                    Size = $_.Size
                    FileSystem = $_.FileSystem
                    GptType = $_.GptType
                }
            })
            Warning = "Execution would erase disk $($Plan.Target.DiskNumber) with identity $($Plan.Target.UniqueId)."
        }
    }
}
