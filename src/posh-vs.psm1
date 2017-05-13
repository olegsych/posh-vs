[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "", Scope="Function", Target="*-PoshVS", Justification="PoshVs is a singular noun")]        
param()

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
Executes Visual Studio 2015's VsDevCmd.bat and copies environment variables it sets
to the current PowerShell session. #>
function Import-VisualStudioEnvironment {
    if (-not $env:VS140COMNTOOLS) {
        Throw "Unable to determine location of Visual Studio 2015. The VS140COMNTOOLS environment is not set."
    }

    [string] $batchFile = (Join-Path $env:VS140COMNTOOLS "VsDevCmd.bat")
    Import-BatchEnvironment $batchFile
}

[string] $importModulePattern = "Import-Module.*posh-vs"
[string] $importEnvironmentPattern = "Import-VisualStudioEnvironment"

<# .SYNOPSIS
Adds Import-Module and Import-VisualStudioEnvironment commands to the current PowerShell profile script. #>
function Install-PoshVs {
    [string[]] $profileScript = @()
    [bool] $importModule = $true
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
