Describe "posh-vs" {
    Import-Module $PSScriptRoot\..\src\posh-vs.psm1

    [string] $originalProfile

    BeforeEach {
        $originalProfile = $global:profile
        $global:profile = Join-Path $env:TEMP ([IO.Path]::GetRandomFileName())
    }

    AfterEach {
        if (Test-Path $global:profile) {
            Remove-Item $global:profile
        }
        $global:profile = $originalProfile
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

    Context "Install-PoshVs" {
        It "Appends Import-VisualStudioEnvironment commands to existing profile script" {
            [string] $existingScript = "Write-Host Foo"
            New-Item -Path $global:profile -ItemType File -Value $existingScript

            Install-PoshVs

            Get-Content $global:profile | Should Be @(
                $existingScript,
                "Import-VisualStudioEnvironment"
            )
        }

        It "Creates new profile script if necessary" {
            Install-PoshVs

            Get-Content $global:profile | Should Be @(
                "Import-VisualStudioEnvironment"
            )
        }

        It "Doesn't duplicate Import-VisualStudioEnvironment command if profile already contains it" {
            @(
                "  Import-VisualStudioEnvironment"
            ) | Out-File $global:profile

            Install-PoshVs

            Get-Content $global:profile | Should Be @(
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
    }

    Context "Uninstall-PoshVs" {
        It "Removes legacy Import-Module from profile script" {
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
    }

    Remove-Module posh-vs
}

Describe 'Get-VisualStudio2015BatchFile' {
    Import-Module $PSScriptRoot\..\src\posh-vs.psm1

    InModuleScope posh-vs {
        [string] $originalPath = $env:VS140ComnTools

        Context '$env:V140ComnTools is defined' {
            $env:VS140ComnTools = Join-Path $env:TEMP ([IO.Path]::GetRandomFileName())

            It 'Returns path to VsDevCmd.bat' {
                Get-VisualStudio2015BatchFile | Should Be (Join-Path $env:VS140ComnTools "VsDevCmd.bat")
            }
        }

        Context '$env:V140ComnTools is not defined' {
            if ($env:VS140ComnTools) {
                Remove-Item 'env:\VS140COMNTOOLS'
            }

            It 'Returns nothing' {
                Get-VisualStudio2015BatchFile | Should BeNullOrEmpty
            }
        }

        $env:VS140ComnTools = $originalPath
    }

    Remove-Module posh-vs
}

Describe 'Get-VisualStudio2017ApplicationDescription' {
    Import-Module $PSScriptRoot\..\src\posh-vs.psm1

    InModuleScope posh-vs {
        Mock Get-ItemProperty {
            # Visual Studio 2017 is not installed
        }

        Context 'In a 64-bit PowerShell process' {
            [string] $vs2017RootPath = Join-Path $env:TEMP ([IO.Path]::GetRandomFileName())
            [string] $applicationDescription1 = "@$(Join-Path $vs2017RootPath ([IO.Path]::GetRandomFileName()))\Common7\IDE\devenvdesc.dll,-1234"
            [string] $applicationDescription2 = "@$(Join-Path $vs2017RootPath ([IO.Path]::GetRandomFileName()))\Common7\IDE\devenvdesc.dll,-1234"
            Mock Get-ItemProperty -MockWith {
                @{ ApplicationDescription = $applicationDescription1 }
                @{ ApplicationDescription = $applicationDescription2 }
            }.GetNewClosure() -ParameterFilter {
                $Path -eq 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\VisualStudio_*\Capabilities'
            }

            It 'Returns ApplicationDescription property HKLM:\SOFTWARE\WOW6432Node' {
                Get-VisualStudio2017ApplicationDescription | Should Be @(
                    $applicationDescription1
                    $applicationDescription2
                )
            }
        }

        Context 'In a 32-bit PowerShell process' {
            [string] $vs2017RootPath = Join-Path $env:TEMP ([IO.Path]::GetRandomFileName())
            [string] $applicationDescription1 = "@$(Join-Path $vs2017RootPath ([IO.Path]::GetRandomFileName()))\Common7\IDE\devenvdesc.dll,-1234"
            [string] $applicationDescription2 = "@$(Join-Path $vs2017RootPath ([IO.Path]::GetRandomFileName()))\Common7\IDE\devenvdesc.dll,-1234"
            Mock Get-ItemProperty -MockWith {
                @{ ApplicationDescription = $applicationDescription1 }
                @{ ApplicationDescription = $applicationDescription2 }
            }.GetNewClosure() -ParameterFilter {
                $Path -eq 'HKLM:\SOFTWARE\Microsoft\VisualStudio_*\Capabilities'
            }

            It 'Returns ApplicationDescription property from HKLM:\SOFTWARE' {
                Get-VisualStudio2017ApplicationDescription | Should Be @(
                    $applicationDescription1
                    $applicationDescription2
                )
            }
        }
    }

    Remove-Module posh-vs
}

Describe 'Get-VisualStudio2017BatchFile' {
    Import-Module $PSScriptRoot\..\src\posh-vs.psm1

    InModuleScope posh-vs {
        Context 'Expected string from Get-VisualStudio2017ApplicationDescription' {
            [string] $vs2017RootPath = Join-Path $env:TEMP ([IO.Path]::GetRandomFileName())
            [string] $instance1RootPath = Join-Path $vs2017RootPath ([IO.Path]::GetRandomFileName())
            [string] $instance2RootPath = Join-Path $vs2017RootPath ([IO.Path]::GetRandomFileName())
            Mock Get-VisualStudio2017ApplicationDescription {
                "@$instance1RootPath\Common7\IDE\devenvdesc.dll,-1234"
                "@$instance2RootPath\Common7\IDE\devenvdesc.dll,-321"
            }.GetNewClosure()

            It 'Returns VsDevCmd.bat paths relative to location of devenvdesc.dll' {
                Get-VisualStudio2017BatchFile | Should Be @(
                    "$instance1RootPath\Common7\Tools\VsDevCmd.bat"
                    "$instance2RootPath\Common7\Tools\VsDevCmd.bat"
                )
            }
        }

        Context 'Unexpected string from Get-VisualStudio2017ApplicationDescription' {
            [string] $unexpected = 'unexpected'
            Mock Get-VisualStudio2017ApplicationDescription {
                $unexpected
            }.GetNewClosure()

            It 'Throws descriptive error' {
                { Get-VisualStudio2017BatchFile } | Should Throw "Cannot parse Visual Studio ApplicationDescription: $unexpected"
            }
        }
    }

    Remove-Module posh-vs
}

Describe 'Get-VisualStudioBatchFile' {
    Import-Module $PSScriptRoot\..\src\posh-vs.psm1

    InModuleScope posh-vs {
        Context 'Multiple versions of Visual Studio are installed' {
            [string] $vs2017BatchFile1 = Join-Path $env:TEMP ([IO.Path]::GetRandomFileName())
            [string] $vs2017BatchFile2 = Join-Path $env:TEMP ([IO.Path]::GetRandomFileName())
            Mock Get-VisualStudio2017BatchFile { @($vs2017BatchFile1, $vs2017BatchFile2) }.GetNewClosure()

            [string] $vs2015BatchFile = Join-Path $env:TEMP ([IO.Path]::GetRandomFileName())
            Mock Get-VisualStudio2015BatchFile { $vs2015BatchFile }.GetNewClosure()

            It 'Returns batch files of Visual Studio 2017 followed by those of Visual Studio 2015' {
                Get-VisualStudioBatchFile | Should Be @($vs2017BatchFile1, $vs2017BatchFile2, $vs2015BatchFile)
            }
        }
    }

    Remove-Module posh-vs
}

Describe 'Import-VisualStudioEnvironment' {
    Import-Module $PSScriptRoot\..\src\posh-vs.psm1

    InModuleScope posh-vs {
        [string] $originalDevEnvDir = $env:DevEnvDir

        Context 'Multiple versions of Visual Studio are installed' {
            $env:DevEnvDir = $null
            [string] $batchFile1 = Join-Path $env:TEMP ([IO.Path]::GetRandomFileName())
            [string] $batchFile2 = Join-Path $env:TEMP ([IO.Path]::GetRandomFileName())
            Mock Get-VisualStudioBatchFile { @($batchFile1, $batchFile2) }.GetNewClosure()
            Mock Import-BatchEnvironment

            It 'Imports batch environment of the first instance' {
                Import-VisualStudioEnvironment
                Assert-MockCalled Import-BatchEnvironment 1 { $batchFile -eq $batchFile1 }
            }
        }

        Context 'Visual Studio environment is already imported' {
            $env:DevEnvDir = Join-Path $env:TEMP ([IO.Path]::GetRandomFileName())
            Mock Import-BatchEnvironment

            It 'Does not import batch environment again' {
                Import-VisualStudioEnvironment
                Assert-MockCalled Import-BatchEnvironment -Exactly 0
            }

            It 'Writes verbose message explaining why environment wasn''t imported again' {
                Mock Write-Verbose -ModuleName posh-vs
                Import-VisualStudioEnvironment
                Assert-MockCalled -CommandName Write-Verbose -ParameterFilter { $message -eq "Visual Studio environment has already been imported from $($env:DevEnvDir)." } -ModuleName posh-vs
            }
        }

        $env:DevEnvDir = $originalDevEnvDir
    }

    Remove-Module posh-vs
}
