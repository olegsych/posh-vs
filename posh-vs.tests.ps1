Describe "posh-vs" {
    Import-Module .\posh-vs.psm1

    function DeleteFile([Parameter(Mandatory = $true)] [string] $file) {
        if (Test-Path $file) {
            Remove-Item $file
        }
    }

    Context "Get-VisualStudioBatchFile" {
        [string] $originalVS140ComnTools

        BeforeEach {
            $originalVS140ComnTools = $env:VS140ComnTools
        }

        It "Returns VsDevCmd.bat from Visual Studio 2015 installation based on VS140COMNTOOLS environment variable" {
            $env:VS140ComnTools = Join-Path $env:TEMP ([IO.Path]::GetRandomFileName())

            $result = Get-VisualStudioBatchFile
            
            $result | Should Be (Join-Path $env:VS140ComnTools "VsDevCmd.bat")
        }

        It "Doesn't return VsDevCmd.bat when Visual Studio 2015 is not installed and VS140COMNTOOLS environment variable isn't defined" {
            if ($env:VS140ComnTools) {
                Remove-Item "env:\VS140COMNTOOLS"
            }

            $result = Get-VisualStudioBatchFile

            $result | Should BeNullOrEmpty
        }

        AfterEach {
            $env:VS140ComnTools = $originalVS140ComnTools
        }
    }

    Context "Import-BatchEnvironment" {
        [string] $batchFile
        [string] $variable
        [string] $value 

        BeforeEach {
            $variable = [guid]::NewGuid()
            $value = "$([guid]::NewGuid())=$([guid]::NewGuid())"
            $batchFile = Join-Path $env:TEMP ([IO.Path]::GetRandomFileName() + ".bat")
        }

        It "Invokes specified batch file and extracts environment variables it sets" {
            "set $variable=$value" | Out-File $batchFile -Encoding ascii
            
            Import-BatchEnvironment -batchFile $batchFile
            
            (Get-Item "env:$variable").Value | Should Be $value
        }

        It "Ignores output of batch file itself to avoid mistaking its output for actual environment variables" {
            "echo $variable=$value"  | Out-File $batchFile -Encoding ascii

            Import-BatchEnvironment -batchFile $batchFile 
            
            Test-Path "env:$variable" | Should Be $false
        }

        It "Throws descriptive exception when specified batch file does not exist" {
            { Import-BatchEnvironment -batchFile $batchFile } | Should Throw "Batch file '$batchFile' does not exist."
        }

        It "Writes verbose message with details about the batch file" {
            "" | Out-File $batchFile -Encoding ascii
            Mock Write-Verbose -ModuleName posh-vs

            Import-BatchEnvironment -batchFile $batchFile

            Assert-MockCalled -CommandName Write-Verbose -ParameterFilter { $message -eq "Executing '$batchFile' to capture environment variables it sets." } -ModuleName posh-vs 
        }

        It "Writes verbose message with details about imported environment variables" {
            "set $variable=$value" | Out-File $batchFile -Encoding ascii
            Mock Write-Verbose -ModuleName posh-vs

            Import-BatchEnvironment -batchFile $batchFile

            Assert-MockCalled -CommandName Write-Verbose -ParameterFilter { $message -eq "`$env:$variable=$value" } -ModuleName posh-vs 
        }

        AfterEach {
            if (Test-Path $batchFile) {
                Remove-Item $batchFile
            }

            if (Test-Path "env:$variable") {
                Remove-Item "env:$variable"
            }
        }
    }

    Context "Import-VisualStudioEnvironment" {
        [string] $originalPath

        BeforeEach {
            $originalPath = $env:VS140ComnTools
        }

        It "Invokes Import-BatchEnvironment with VS2015 VsDevCmd.bat" {
            $env:VS140ComnTools = Join-Path $env:TEMP ([IO.Path]::GetRandomFileName())
            Mock Import-BatchEnvironment -ModuleName posh-vs

            Import-VisualStudioEnvironment

            [string] $expectedBatchFile = (Join-Path $env:VS140ComnTools "VsDevCmd.bat") 
            Assert-MockCalled -CommandName Import-BatchEnvironment -ParameterFilter { $batchFile -eq $expectedBatchFile } -ModuleName posh-vs
        }

        It "Throws descriptive exception when VS140COMNTOOLS environment variable is not set" {
            if ($env:VS140ComnTools) {
                Remove-Item "env:\VS140COMNTOOLS"
            }

            { Import-VisualStudioEnvironment } | Should Throw "Unable to determine location of Visual Studio 2015. The VS140COMNTOOLS environment is not set."
        }

        AfterEach {
            $env:VS140ComnTools = $originalPath
        }
    }

    Context "Install-PoshVs" {
        [string] $originalProfile

        BeforeEach {
            $originalProfile = $global:profile
            $global:profile = Join-Path $env:TEMP ([IO.Path]::GetRandomFileName())
        }

        It "Appends Import-Module and Import-VisualStudioEnvironment commands to existing profile script" {
            [string] $existingScript = "Write-Host Foo"
            New-Item -Path $global:profile -ItemType File -Value $existingScript

            Install-PoshVs

            Get-Content $global:profile | Should Be @(
                $existingScript,
                "Import-Module posh-vs",
                "Import-VisualStudioEnvironment"
            )
        }

        It "Creates new profile script if necessary" {
            Install-PoshVs

            Get-Content $global:profile | Should Be @(
                "Import-Module posh-vs",
                "Import-VisualStudioEnvironment"
            )
        }

        It "Doesn't duplicate Import-Module command if profile script already contains it" {
            @(
                "  Import-Module   posh-vs"
            ) | Out-File $global:profile

            Install-PoshVs

            Get-Content $global:profile | Should Be @(
                "  Import-Module   posh-vs",
                "Import-VisualStudioEnvironment"
            )
        }

        It "Doesn't duplicate Import-VisualStudioEnvironment command if profile already contains it" {
            @(
                "  Import-VisualStudioEnvironment"
            ) | Out-File $global:profile

            Install-PoshVs

            Get-Content $global:profile | Should Be @(
                "Import-Module posh-vs",
                "  Import-VisualStudioEnvironment"
            )
        }

        It "Writes to output to explain what's going on" {
            Install-PoshVs | Should Be @(
                "Successfully added posh-vs to profile '$global:profile'."
                "Reload your profile for the changes to take effect:"
                "    . `$profile"
            )
        }

        AfterEach {
            DeleteFile $global:profile
            $global:profile = $originalProfile
        }
    }

    Context "Uninstall-PoshVs" {
        [string] $originalProfile

        BeforeEach {
            $originalProfile = $global:profile
            $global:profile = Join-Path $env:TEMP ([IO.Path]::GetRandomFileName())
        }

        It "Removes Import-Module from profile script" {
            "    Import-Module   posh-vs   " | Out-File $global:profile

            Uninstall-PoshVs

            Get-Content $global:profile | Should BeNullOrEmpty
        }

        It "Removes Import-VisualStudioEnvironment from profile script" {
            "    Import-VisualStudioEnvironment   " | Out-File $global:profile

            Uninstall-PoshVs

            Get-Content $global:profile | Should BeNullOrEmpty
        }

        It "Preserves code unrelated to posh-vs" {
            [string[]] $expected = @( "Write-Host Foo")
            $expected | Out-File $global:profile
            
            Uninstall-PoshVs
            
            [string[]] $actual = Get-Content $global:profile 
            $actual | Should Be $expected
        }

        It "Writes to host to explain what's going on" {
            Uninstall-PoshVs | Should Be @(
                "Successfully removed posh-vs from profile '$global:profile'."
                "Restart PowerShell for the changes to take effect."
            )
        }

        AfterEach {
            DeleteFile $global:profile
            $global:profile = $originalProfile
        }
    }

    Remove-Module posh-vs
}