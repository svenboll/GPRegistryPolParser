# GPRegistryPolParser #
Group Policy Registry Policy - Parser module for Registry.pol files

The Policy entries in this files are registry settings stored in the following path 'Software\Policies'.

Documentation of the registry.pol file format can be found here [MS-GPREG Format](https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-gpreg/5c092c22-bf6b-4e7f-b180-b20743d368f5)

## Exported Functions ##

With this module it is possible to read, write, create and append entries to any registry policy file within a Microsoft Group Policy Object, wheather it is computer or user based. 

| Command | Description
| --- | ---
| Import-GPRegistryPolFile | Read and parses a registry.pol file. You will get an array of settings with following attributes (Key, Value, Type, Size, Data)
| Export-GPRegistryPolFile | Write a set of registry settings to a (new) registry.pol file
| New-GPRegistryPolFile | Creates a new registry.pol file and write file signature and version
| Add-GPRegistryPolFileEntry | Add setting entries to an existing registry.pol file


