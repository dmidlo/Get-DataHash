# Module manifest for module 'Get-DataHash'

@{
    RootModule = 'Get-DataHash.psm1'
    ModuleVersion = '0.91.1'
    CompatiblePSEditions = @('Core', 'Desktop')
    GUID = 'f40df9ce-7a64-46fa-bab3-dd870cbfc091'
    Author = 'David Midlo'
    Copyright = '(c) 2025 David Midlo. Licensed under the MIT License.'
    Description = 'A PowerShell module for generating hash digests of complex Powershell/.Net data structures, supporting various hashing algorithms, intuitive structural normalization for hash consistency, and circular reference handling. Ideal for data integrity verification and digest generation of powershell objects.'
    PowerShellVersion = '7.0'
    DotNetFrameworkVersion = '4.7.2'
    ClrVersion = '4.0'
    RequiredAssemblies = 'LiteDB.dll'
    FunctionsToExport = @()
    CmdletsToExport = @()
    VariablesToExport = '*'
    AliasesToExport = @()
    DscResourcesToExport = @()
    ModuleList = @()
    PrivateData = @{
        PSData = @{
            Tags = @('hashing', 'data', 'cryptography', 'security', 'PowerShell')
            LicenseUri = 'https://opensource.org/licenses/MIT'
            ProjectUri = 'https://github.com/davidmidlo/Get-DataHash'
            ReleaseNotes = 'Initial release of Get-DataHash module with support for SHA-256, object normalization, and BSON serialization.'
            Prerelease = ''
            RequireLicenseAcceptance = $false
            ExternalModuleDependencies = @()
        }
    
    }
    HelpInfoURI = 'https://github.com/dmidlo/Get-DataHash/'
    DefaultCommandPrefix = 'DataHash'
}
 