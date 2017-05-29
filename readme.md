# posh-vs

Makes Visual Studio command line tools available in PowerShell. Supports Visual Studio 2017 and 2015.

## Usage

Install posh-vs from the [PowerShell Gallery](https://www.powershellgallery.com/packages/posh-vs):
```
PS> Install-Module posh-vs -Scope CurrentUser
```

Change your PowerShell profile to automatically import Visual Studio developer environment.
```
PS> Install-PoshVs
```

Start a new PowerShell session or reload your profile:
```
PS> . $profile
```

Use Visual Studio command line tools in PowerShell:
``` 
PS> msbuild /?
```

## How it works

`Install-PoshVs` adds an `Import-VisualStudioBatchEnvironment` call to the PowerShell
[profile](https://msdn.microsoft.com/en-us/powershell/reference/5.1/microsoft.powershell.core/about/about_profiles).
It will import the environment variables set by the `VsDevCmd.bat` of the latest version of Visual Studio installed
on your computer. If multiple instances of Visual Studio 2017 are installed, `Import-VisualStudioBatchEnvironment`
will use whichever instance happens to be listed first.

To use a specific instance of Visual Studio 2017, manually change your profile to import a specific batch file.
```
Import-BatchEnvironment 'C:\Program Files (x86)\Microsoft Visual Studio\2017\Community\Common7\Tools\VsDevCmd.bat'
```

## Uninstall

Remove posh-vs from your PowerShell profile.
```
PS> Uninstall-PoshVs
PS> exit
```

Uninstall posh-vs from your computer.
```
PS> Uninstall-Module posh-vs
```

## Develop

[![Build status](https://ci.appveyor.com/api/projects/status/github/olegsych/posh-vs?branch=master)](https://ci.appveyor.com/project/olegsych/posh-vs/branch/master)

Install pre-requisites.
```
PS> .\init.ps1
```

`Ctrl+Shift+B` to build and test in [VSCode](https://code.visualstudio.com) or
```
PS> Invoke-psake
```

`F5` to debug tests in VSCode.

## Credits

posh-vs was inspired by [Alen Mack](http://allen-mack.blogspot.com/2008/03/replace-visual-studio-command-prompt.html), 
[StackOverflow contributors](http://stackoverflow.com/questions/2124753/how-i-can-use-powershell-with-the-visual-studio-command-prompt)
and [posh-git](https://github.com/dahlbyk/posh-git).
