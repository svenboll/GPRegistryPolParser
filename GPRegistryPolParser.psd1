@{

    # Script module or binary module file associated with this manifest.
    RootModule = 'GPRegistryPolParser.psm1'

    #DscResourcesToExport = ''

    # Version number of this module.
    ModuleVersion = '2025.0'

    # ID used to uniquely identify this module
    GUID = '3d9f03f4-fd3c-4508-afb7-832f2fe96b84'

    # Author of this module
    Author = 'Sven Boll'

    # Company or vendor of this module
    CompanyName = 'ThumbsUP IT - Sven Boll'

    # Copyright statement for this module
    Copyright = '(c) 2025 Sven Boll. All rights reserved.'

    # Description of the functionality provided by this module
    Description = 'Module with parser cmdlets to work with GroupPolicy Registry.pol files'

    # Minimum version of the Windows PowerShell engine required by this module
    PowerShellVersion = '5.0'

    # Name of the Windows PowerShell host required by this module
    # PowerShellHostName = ''

    # Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
    PrivateData = @{

        PSData = @{

            # Prerelease = 'prerelease'

            # Tags applied to this module. These help with module discovery in online galleries.
            Tags = @('GroupPolicy', 'Registry.pol')

            # A URL to the license for this module.
            LicenseUri = 'https://github.com/svenboll/GPRegistryPolParser/blob/main/LICENSE'

            # A URL to the main website for this project.
            ProjectUri = 'https://github.com/svenboll/GPRegistryPolParser'

            # A URL to an icon representing this module.
            # IconUri = ''

        } # End of PSData hashtable

    } # End of PrivateData hashtable

    FunctionsToExport = @('Read-PolFile','New-GPRegistryPolicyFile','Add-RegistryPolicies','New-RegistrySettingsEntry')
}
