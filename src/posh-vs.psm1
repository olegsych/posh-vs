[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "", Scope="Function", Target="*-PoshVS", Justification="PoshVs is a singular noun")]
param()

function Get-VisualStudio2015BatchFile {
    if ($env:VS140ComnTools) {
        Join-Path $env:VS140ComnTools "VsDevCmd.bat"
    }
}

function Get-VisualStudio2017ApplicationDescription {
    & {
        Get-ItemProperty HKLM:\SOFTWARE\WOW6432Node\Microsoft\VisualStudio_*\Capabilities
        Get-ItemProperty HKLM:\SOFTWARE\Microsoft\VisualStudio_*\Capabilities
    } | ForEach-Object { $_.ApplicationDescription }
}

function Get-VisualStudio2017BatchFile {
    Get-VisualStudio2017ApplicationDescription |
    ForEach-Object {
        # @C:\Program Files (x86)\Microsoft Visual Studio\2017\Community\Common7\IDE\devenvdesc.dll,-1004
        if ($_ -match '@(?<Common7>.*)\\IDE\\devenvdesc.dll,-(?:\d*)') {
            return Join-Path $matches.Common7 'Tools\VsDevCmd.bat'
        }

        throw "Cannot parse Visual Studio ApplicationDescription: $_"
    }
}

function Get-VisualStudioBatchFile {
    Get-VisualStudio2017BatchFile
    Get-VisualStudio2015BatchFile
}

<# .SYNOPSIS
Executes a batch file and copies environment variables it sets to the current
PowerShell session #>
function Import-BatchEnvironment {
    [CmdletBinding()] param (
        [Parameter(Mandatory = $true)] [string] $batchFile
    )

    if (-not (Test-Path $batchFile)) {
        Throw "Batch file '$batchFile' does not exist."
    }

    Write-Verbose "Executing '$batchFile' to capture environment variables it sets."
    cmd /c "`"$batchFile`" > nul & set" | ForEach-Object {
        if ($_ -match "^(.+?)=(.*)$") {
            [string] $variable = $matches[1]
            [string] $value = $matches[2]
            Write-Verbose "`$env:$variable=$value"
            Set-Item -Force -Path "env:\$variable" -Value $value
        }
    }
}

<# .SYNOPSIS
Executes Visual Studio's VsDevCmd.bat and copies the environment variables it sets
to the current PowerShell session. #>
function Import-VisualStudioEnvironment {
    [CmdletBinding()] param ()

    if ($env:DevEnvDir) {
        Write-Verbose "Visual Studio environment has already been imported from $($env:DevEnvDir)."
        return
    }

    [string] $batchFile = Get-VisualStudioBatchFile | Select-Object -First 1
    Import-BatchEnvironment $batchFile
}

[string] $importModulePattern = "Import-Module.*posh-vs"
[string] $importEnvironmentPattern = "Import-VisualStudioEnvironment"

<# .SYNOPSIS
Adds Import-Module and Import-VisualStudioEnvironment commands to the current PowerShell profile script. #>
function Install-PoshVs {
    [CmdletBinding()] param ()

    [string[]] $profileScript = @()
    [bool] $importEnvironment = $true
    if (Test-Path $profile) {
        $profileScript = Get-Content $profile
        foreach ($line in $profileScript) {
            if ($line -match $importEnvironmentPattern) {
                $importEnvironment = $false
            }
        }
    }

    if ($importEnvironment) {
        $profileScript += "Import-VisualStudioEnvironment"
    }

    $profileScript | Out-File $profile

    Write-Output "Successfully added posh-vs to profile '$profile'."
    Write-Output "Reload your profile for the changes to take effect:"
    Write-Output "    . `$profile"
}

<# .SYNOPSIS
Removes Import-Module and Import-VisualStudioEnvironment from the current PowerShell profile script. #>
function Uninstall-PoshVs {
    [CmdletBinding()] param ()

    if (Test-Path $profile) {
        [string[]] $script = Get-Content $profile
        $script | Where-Object {
            -not ($_ -match $importModulePattern) -and
            -not ($_ -match $importEnvironmentPattern)
        } | Out-File $profile
    }

    Write-Output "Successfully removed posh-vs from profile '$profile'."
    Write-Output "Restart PowerShell for the changes to take effect."
}

Export-ModuleMember -Function Import-BatchEnvironment
Export-ModuleMember -Function Import-VisualStudioEnvironment
Export-ModuleMember -Function Install-PoshVs
Export-ModuleMember -Function Uninstall-PoshVs
