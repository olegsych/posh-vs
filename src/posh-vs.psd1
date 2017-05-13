@{
    RootModule = 'posh-vs.psm1'
    ModuleVersion = '$moduleVersion'
    GUID = 'fbcfcfe0-702c-483c-915d-6b0b78433e24'
    Author = 'Oleg Sych'
    Copyright = '(c) 2015 Oleg Sych. All rights reserved.'
    Description = 'Makes Visual Studio 2015 command line tools available in PowerShell.'
    FunctionsToExport = '*'
    PrivateData = @{
        PSData = @{
            Tags = @('VisualStudio', 'MSBuild')
            LicenseUri = 'https://github.com/olegsych/posh-vs/blob/master/LICENSE'
            ProjectUri = 'https://github.com/olegsych/posh-vs'
        }
    }
}
