# posh-vs

Makes Visual Studio 2015 command line tools available in PowerShell. 

## Usage

Install posh-vs from the [PowerShell Gallery](https://www.powershellgallery.com/packages/posh-vs):
``` 
PS> Install-Module posh-vs
PS> Install-PoshVs
``` 

Start a new PowerShell session or reload your profile:
``` 
PS> . $profile
```

Use Visual Studio 2015 command line tools in PowerShell:
``` 
PS> msbuild /?
```

## Uninstall

``` 
PS> Uninstall-PoshVs
PS> Uninstall-Module posh-vs
PS> exit
```

## Development

Install pre-requisites.
``` 
PS> .\init.ps1
```

Run tests to verify code changes:
``` 
PS> Invoke-Pester
```

Run script analyzer to verify compliance with the PowerShell Gallery requirements:
``` 
PS> Invoke-ScriptAnalyzer .\posh-vs.psm1
PS> Invoke-ScriptAnalyzer .\posh-vs.tests.ps1
```

Verify module manifest changes: 
```
PS> Test-ModuleManifest .\posh-vs.psd1
```

Publish to PowerShell Gallery:
```
PS> Publish-Module -Path .\ -NuGetApiKey $yourApiKey
```

## Credits

posh-vs was inspired by [Alen Mack](http://allen-mack.blogspot.com/2008/03/replace-visual-studio-command-prompt.html), 
[StackOverflow contributors](http://stackoverflow.com/questions/2124753/how-i-can-use-powershell-with-the-visual-studio-command-prompt)
and [posh-git](https://github.com/dahlbyk/posh-git).
