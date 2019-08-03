# psake build definition
# https://github.com/psake/psake

param(
  [System.Version] $moduleVersion = '0.0.0'
)

$ErrorActionPreference = "Stop"

Properties {
    $outputDirectory = "out"
    $moduleDirectory = $outputDirectory + "\posh-vs"
}

Task default -Depends Build, Test

Task Clean {
    if (Test-Path $outputDirectory) {
        Remove-Item $outputDirectory -Recurse -Force
    }

    New-Item -ItemType Directory $outputDirectory | Write-Verbose
    New-Item -ItemType Directory $moduleDirectory | Write-Verbose
} 

Task BuildScript -Depends Clean {
    Invoke-ScriptAnalyzer .\src\posh-vs.psm1
    Copy-Item .\src\posh-vs.psm1 -Destination $moduleDirectory
}

Task BuildManifest -Depends Clean {
    $source = Get-Content .\src\posh-vs.psd1

    $expanded = @()
    foreach ($line in $source) {
        $expanded += $ExecutionContext.InvokeCommand.ExpandString($line)
    }

    $expanded | Out-File $moduleDirectory\posh-vs.psd1

    Test-ModuleManifest $moduleDirectory\posh-vs.psd1 | Write-Verbose
}

Task Build -Depends BuildScript, BuildManifest

Task Test {
    $tests = Invoke-Pester -Script .\test\posh-vs.tests.ps1 -PassThru
    Assert ($tests.FailedCount -eq 0) "$($tests.FailedCount) test(s) failed." 
}

Task Publish -Depends BuildScript, BuildManifest {
     Publish-Module -Path $moduleDirectory -NuGetApiKey $env:PowerShellGalleryApiKey
}
