Task default -Depends Build, Test

Task Build {
    Invoke-ScriptAnalyzer .\posh-vs.psm1
    Test-ModuleManifest .\posh-vs.psd1
}

Task Test {
    Invoke-Pester
}

