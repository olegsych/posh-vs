Task default -Depends Build, Test

Task Build {
    Invoke-ScriptAnalyzer .\src\posh-vs.psm1
    Test-ModuleManifest .\src\posh-vs.psd1
}

Task Test {
    Invoke-Pester -Script .\test\posh-vs.tests.ps1 -EnableExit
}

Task Publish {
     Publish-Module -Path .\ -NuGetApiKey $env:PowerShellApiKey
}
