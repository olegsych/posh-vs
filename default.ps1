# psake build definition

Task default -Depends Build, Test

Properties {
    $moduleVersion = if ($env:APPVEYOR) { $env:APPVEYOR_BUILD_VERSION } else { '0.0.0' }
}

Task Clean {
    Remove-Item .\out -Recurse -Force
    New-Item -ItemType Directory out | Write-Verbose
}

Task BuildScript -Depends Clean {
    Invoke-ScriptAnalyzer .\src\posh-vs.psm1
    Copy-Item .\src\posh-vs.psm1 -Destination .\out\
}

Task BuildManifest -Depends Clean {
    $source = Get-Content .\src\posh-vs.psd1

    $expanded = @()
    foreach ($line in $source) {
        $expanded += $ExecutionContext.InvokeCommand.ExpandString($line)
    }

    $expanded | Out-File .\out\posh-vs.psd1

    Test-ModuleManifest .\out\posh-vs.psd1 | Write-Verbose
}

Task Build -Depends BuildScript, BuildManifest

Task Test {
    Invoke-Pester -Script .\test\posh-vs.tests.ps1 -EnableExit
}

Task Publish {
     Publish-Module -Path .\out\ -NuGetApiKey $env:PowerShellGalleryApiKey
}
