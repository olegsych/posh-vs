[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "", Scope="Function", Target="*-PoshVS", Justification="PoshVs is a singular noun")]        
param()

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

function Import-VisualStudioEnvironment {
    if (-not $env:VS140COMNTOOLS) {
        Throw "Unable to determine location of Visual Studio 2015. The VS140COMNTOOLS environment is not set."
    }

    [string] $batchFile = (Join-Path $env:VS140COMNTOOLS "VsDevCmd.bat")
    Import-BatchEnvironment $batchFile
}

[string] $importModulePattern = "Import-Module.*posh-vs"
[string] $importEnvironmentPattern = "Import-VisualStudioEnvironment"

function Install-PoshVs {
    [string[]] $profileScript = @()
    [bool] $importModule = $true
    [bool] $importEnvironment = $true
    if (Test-Path $profile) {
        $profileScript = Get-Content $profile
        foreach ($line in $profileScript) {
            if ($line -match $importModulePattern) {
                $importModule = $false
            }
            if ($line -match $importEnvironmentPattern) {
                $importEnvironment = $false
            }
        }
    }

    if ($importModule) {
        $profileScript += "Import-Module posh-vs"
    }

    if ($importEnvironment) {
        $profileScript += "Import-VisualStudioEnvironment" 
    }
    
    $profileScript | Out-File $profile

    Write-Host "Successfully added posh-vs to profile '$profile'."
    Write-Host "Reload your profile for the changes to take effect:"
    Write-Host "    . `$profile"
}

function Uninstall-PoshVs {
    if (Test-Path $profile) {
        [string[]] $script = Get-Content $profile
        $script | Where-Object { 
            -not ($_ -match $importModulePattern) -and
            -not ($_ -match $importEnvironmentPattern)
        } | Out-File $profile
    }
    
    Write-Host "Successfully removed posh-vs from profile '$profile'."
    Write-Host "Restart PowerShell for the changes to take effect."
}

Export-ModuleMember -Function Import-BatchEnvironment
Export-ModuleMember -Function Import-VisualStudioEnvironment
Export-ModuleMember -Function Install-PoshVs
Export-ModuleMember -Function Uninstall-PoshVs