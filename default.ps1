Task default -Depends Test, AnalyzeScripts, TestManifest

Task Test {
    Invoke-Pester
}

Task AnalyzeScripts {
    Invoke-ScriptAnalyzer .\posh-vs.psm1
}

Task TestManifest {
    Test-ModuleManifest .\posh-vs.psd1
}
