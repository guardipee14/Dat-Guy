BeforeAll {
    $projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
    Import-Module (Join-Path $projectRoot 'Phoenix.psd1') -Force 6>$null
}

AfterAll {
    Remove-Module Phoenix -Force -ErrorAction SilentlyContinue
}

Describe 'Get-PhoenixDeploymentPrerequisite' -Tag @('Unit', 'Deployment', 'ADK', 'WinPE') {
    It 'reports every missing required prerequisite without mutating the host' {
        $result = Get-PhoenixDeploymentPrerequisite -KitsRoot (Join-Path $TestDrive 'missing-adk') -HostArchitecture x64

        $result.Ready | Should-BeFalse
        $result.Tools.Count | Should-Be 5
        $result.MissingPrerequisites.Count | Should-BeGreaterThan 0
        $result.IsValid() | Should-BeTrue
    }

    It 'accepts a complete supported ADK and WinPE fixture' {
        $kitsRoot = Join-Path $TestDrive 'kits'
        $winpeRoot = Join-Path $kitsRoot 'Assessment and Deployment Kit\Windows Preinstallation Environment'
        $paths = @(
            (Join-Path $kitsRoot 'Assessment and Deployment Kit\Deployment Tools\amd64\DISM\dism.exe')
            (Join-Path $kitsRoot 'Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe')
            (Join-Path $winpeRoot 'amd64\en-us\winpe.wim')
        )

        foreach ($path in $paths) {
            $null = New-Item -ItemType Directory -Path (Split-Path $path -Parent) -Force
            [IO.File]::WriteAllText($path, 'fixture')
        }

        $null = New-Item -ItemType Directory -Path (Join-Path $winpeRoot 'amd64\Media') -Force

        $result = Get-PhoenixDeploymentPrerequisite -KitsRoot $kitsRoot -WinPERoot $winpeRoot -HostArchitecture x64

        $result.Ready | Should-Be $IsWindows
        $result.HostSupported | Should-Be $IsWindows
        @($result.Tools | Where-Object Required | Where-Object { -not $_.Available }).Count | Should-Be 0
        $result.IsValid() | Should-BeTrue
    }

    It 'rejects non-x64 host architecture at the readiness gate' {
        $result = Get-PhoenixDeploymentPrerequisite -KitsRoot (Join-Path $TestDrive 'adk') -HostArchitecture Arm64

        $result.HostSupported | Should-BeFalse
        $result.Ready | Should-BeFalse
        ($result.MissingPrerequisites -join '|') | Should-MatchString 'Supported x64 Windows host'
    }
}
