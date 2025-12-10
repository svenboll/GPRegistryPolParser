###########################################################
#
#   Group Policy - Registry.pol parser module
#
#   Copyright (c) Sven Boll, 2025
#
#   Credit history:
#   Module:     GPRegistryPolicyParser
#   Company:    (c) Microsoft Corporation, 2016
#
###########################################################

# Add compatibility for Powershell Core which does not support 'encoding byte' via splatting
if ($PSVersionTable.PSVersion.Major -gt "5")
{
    $byteParam = @{AsByteStream = $True}
} else
{
    $byteParam = @{Encoding = "Byte"}
}

$NullTerminator = "`0"

$script:REGFILE_SIGNATURE = 0x67655250 # "PReg"
$script:REGISTRY_FILE_VERSION = 0x00000001 # defined as 1

Enum RegType {
    REG_NONE                       = 0	# No value type
    REG_SZ                         = 1	# Unicode null terminated string
    REG_EXPAND_SZ                  = 2	# Unicode null terminated string (with environmental variable references)
    REG_BINARY                     = 3	# Free form binary
    REG_DWORD                      = 4	# 32-bit number
    REG_DWORD_LITTLE_ENDIAN        = 4	# 32-bit number (same as REG_DWORD)
    REG_DWORD_BIG_ENDIAN           = 5	# 32-bit number
    REG_LINK                       = 6	# Symbolic link (Unicode)
    REG_MULTI_SZ                   = 7	# Multiple Unicode strings, delimited by \0, terminated by \0\0
    REG_RESOURCE_LIST              = 8  # Resource list in resource map
    REG_FULL_RESOURCE_DESCRIPTOR   = 9  # Resource list in hardware description
    REG_RESOURCE_REQUIREMENTS_LIST = 10
    REG_QWORD                      = 11 # 64-bit number
    REG_QWORD_LITTLE_ENDIAN        = 11 # 64-bit number (same as REG_QWORD)
}

Class GPRegistryPolicy
{
    [string]  $KeyName
    [string]  $ValueName
    [RegType] $ValueType
    [Int32]   $ValueLength
    [object]  $ValueData

    GPRegistryPolicy()
    {
        $this.KeyName     = $Null
        $this.ValueName   = $Null
        $this.ValueType   = [RegType]::REG_NONE
        $this.ValueLength = 0
        $this.ValueData   = $Null
    }

    GPRegistryPolicy(
            [string]  $KeyName,
            [string]  $ValueName,
            [RegType] $ValueType,
            [Int32]   $ValueLength,
            [object]  $ValueData
        )
    {
        $this.KeyName     = $KeyName
        $this.ValueName   = $ValueName
        $this.ValueType   = $ValueType
        $this.ValueLength = $ValueLength
        $this.ValueData   = $ValueData
    }
}

Function New-GPRegistryPolicy
{
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]
        $keyName,

        [Parameter(Position = 1)]
        [string]
        $valueName = $null,

        [Parameter(Position = 2)]
        [RegType]
        $valueType = [RegType]::REG_NONE,

        [Parameter(Position = 3)]
        [Int32]
        $valueLength = $null,

        [Parameter(Position = 4)]
        [object]
        $valueData = $null
    )

    $Policy = [GPRegistryPolicy]::new($keyName, $valueName, $valueType, $valueLength, $valueData)

    return $Policy;
}

<#
.SYNOPSIS
Reads and parses a .pol file.

.DESCRIPTION
Reads a .pol file, parses it and returns an array of Group Policy registry settings.

.PARAMETER Path
Specifies the path to the .pol file.

.EXAMPLE
C:\PS> Read-PolFile -Path "C:\Registry.pol"
#>
Function Read-PolFile
{
    [OutputType([GPRegistryPolicy[]])]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Path
    )

    [GPRegistryPolicy[]] $RegistryPolicies = @()
    [int] $index = 0

    [string] $policyContents = Get-Content $Path -Raw
    [byte[]] $policyContentInBytes = Get-Content $Path -Raw @byteParam

    # 4 bytes are the signature PReg
    $signature = [System.Text.Encoding]::ASCII.GetString($policyContents[($index)..3])
    Assert ($signature -eq "Preg") "Invalid header signature in file $($Path)"
    $index += 4

    # 4 bytes are the version
    $version = [System.BitConverter]::ToInt32($policyContentInBytes, $index)
    Assert ($version -eq $script:REGISTRY_FILE_VERSION) "Invalid header version in file $($Path)"
    $index += 4

    # Start processing at byte 8
    while($index -lt $policyContents.Length - 2)
    {
        [string]  $keyName = $null
        [string]  $valueName = $null
        [RegType] $valueType = [RegType]::REG_NONE
        [Int32]   $valueLength = $null
        [object]  $value = $null

        # Next UNICODE character should be a [
        $leftbracket = [System.BitConverter]::ToChar($policyContentInBytes, $index)
        Assert ($leftbracket -eq '[') "Missing the openning bracket"
        $index += 2

        # Next UNICODE string will continue until the ";" and should be null-terminated
        $semicolon = $policyContents.IndexOf(";", $index)
        Assert ($semicolon -ge 0) "Failed to locate the semicolon after key name."
        $keyName = [System.Text.Encoding]::UNICODE.GetString($policyContents[($index)..($semicolon-1)])
        Assert ($keyName.EndsWith($NullTerminator)) "Missing null-termination in key parameter"
        $keyName = $keyName.TrimEnd($NullTerminator)
        $index = $semicolon + 2

        # Next UNICODE string will continue until the ";" and should be null-terminated
        $semicolon = $policyContents.IndexOf(";", $index)
        Assert ($semicolon -ge 0) "Failed to locate the semicolon after value name."
        $valueName = [System.Text.Encoding]::UNICODE.GetString($policyContents[($index)..($semicolon-1)])
        Assert ($valueName.EndsWith($NullTerminator)) "Missing null-termination in value parameter"
        $valueName = $valueName.TrimEnd($NullTerminator)
        $index = $semicolon + 2

        # Next DWORD will continue until the ;
        $semicolon = $index + 4 # DWORD Size
        Assert ([System.BitConverter]::ToChar($policyContentInBytes, $semicolon) -eq ';') "Failed to locate the semicolon after value type."
        $valueType = [System.BitConverter]::ToInt32($policyContentInBytes, $index)
        $index = $semicolon + 2

        # Next DWORD will continue until the ;
        $semicolon = $index + 4 # DWORD Size
        Assert ([System.BitConverter]::ToChar($policyContentInBytes, $semicolon) -eq ';') "Failed to locate the semicolon after value length."
        $valueLength = [System.BitConverter]::ToInt32($policyContentInBytes, $index)
        $index = $semicolon + 2

        if ($valueLength -gt 0)
        {
            # REG_SZ: string type
            if($valueType -eq [RegType]::REG_SZ)
            {
                [string] $value = [System.Text.Encoding]::UNICODE.GetString($policyContents[($index)..($index+$valueLength-3)]) # -3 to exclude the null termination and ']' characters
                $index += $valueLength
            }

            # REG_EXPAND_SZ: string, includes %ENVVAR% (expanded by caller)
            if($valueType -eq [RegType]::REG_EXPAND_SZ)
            {
                [string] $value = [System.Text.Encoding]::UNICODE.GetString($policyContents[($index)..($index+$valueLength-3)]) # -3 to exclude the null termination and ']' characters
                $index += $valueLength
            }

            # REG_MULTI_SZ: multiple strings, delimited by \0, terminated by \0\0
            if($valueType -eq [RegType]::REG_MULTI_SZ)
            {
                [string] $rawValue = [System.Text.Encoding]::UNICODE.GetString($policyContents[($index)..($index + $valueLength - 3)])
                $value = Format-MultiStringValue -MultiStringValue $rawValue
                $index += $valueLength
            }

            # REG_BINARY: binary values
            if($valueType -eq [RegType]::REG_BINARY)
            {
                [byte[]] $value = $policyContentInBytes[($index)..($index + $valueLength - 1)]
                $index += $valueLength
            }
        }

        # DWORD: (4 bytes) in little endian format
        if($valueType -eq [RegType]::REG_DWORD)
        {
            $value = Convert-StringToInt -ValueString $policyContentInBytes[$index..($index+3)]
            $index += 4
        }

        # QWORD: (8 bytes) in little endian format
        if($valueType -eq [RegType]::REG_QWORD)
        {
            $value = Convert-StringToInt -ValueString $policyContentInBytes[$index..($index+7)]
            $index += 8
        }

        # Next UNICODE character should be a ]
        $rightbracket = $policyContents.IndexOf("]", $index)
        Assert ($rightbracket -ge 0) "Missing the closing bracket."
        $index = $rightbracket + 2

        $entry = New-GPRegistryPolicy $keyName $valueName $valueType $valueLength $value

        $RegistryPolicies += $entry
    }

    return $RegistryPolicies
}

<#
.SYNOPSIS
Creates a new file / Overwrites existing file

.DESCRIPTION
Creates a file and initializes it with Group Policy Registry file format signature and version.

.PARAMETER Path
Path to a file (.pol extension)
#>
Function New-GPRegistryPolicyFile
{
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Path,

        [switch]
        $Force
    )

    if (Test-Path -Path $Path -ErrorAction SilentlyContinue) {
        # Overwrite only when -Force parameter is set
        Assert ($Force) "File $($Path) exists, please specify a different path or use parameter -Force."
        $null = Remove-Item -Path $Path -Force -ErrorAction SilentlyContinue
    }

    New-Item -Path $Path -Force -ErrorAction Stop | Out-Null

    [System.BitConverter]::GetBytes($script:REGFILE_SIGNATURE) | Add-Content -Path $Path @byteParam
    [System.BitConverter]::GetBytes($script:REGISTRY_FILE_VERSION) | Add-Content -Path $Path @byteParam
}

<#
.SYNOPSIS
Creates a .pol file entry byte array from a GPRegistryPolicy instance.

.DESCRIPTION
Creates a .pol file entry byte array from a GPRegistryPolicy instance. This entry can be written
in a .pol file later.

.PARAMETER RegistryPolicy
Specifies the registry policy entry.
#>
Function New-RegistrySettingsEntry
{
    [OutputType([Array])]
    param (
		[Parameter(Mandatory = $true)]
        [alias("RP")]
        [GPRegistryPolicy]
        $RegistryPolicy
    )
        
    # Entry format: [key;value;type;size;data]
    [Byte[]] $Entry = @()
        
    $Entry += [System.Text.Encoding]::Unicode.GetBytes('[') # Openning bracket
        
    $Entry += [System.Text.Encoding]::Unicode.GetBytes($RP.KeyName + $NullTerminator)

    $Entry += [System.Text.Encoding]::Unicode.GetBytes(';') # semicolon as delimiter

    $Entry += [System.Text.Encoding]::Unicode.GetBytes($RP.ValueName + $NullTerminator)

    $Entry += [System.Text.Encoding]::Unicode.GetBytes(';') # semicolon as delimiter

    $Entry += [System.BitConverter]::GetBytes([Int32]$RP.ValueType)

    $Entry += [System.Text.Encoding]::Unicode.GetBytes(';') # semicolon as delimiter

    # Get data bytes then compute byte size based on data and type
    switch ($RP.ValueType)
    {
        {@([RegType]::REG_SZ, [RegType]::REG_EXPAND_SZ) -contains $_ }
            {
                $dataBytes = [System.Text.Encoding]::Unicode.GetBytes($RP.ValueData + $NullTerminator)
                $dataSize = $dataBytes.Count
            }

        ([RegType]::REG_MULTI_SZ)
            {
                <#
                    When REG_MULTI_SZ ValueData contains an array, we need to null terminate each item. Furthermore
                    "Data in the Data field to be interpreted as a sequence of characters terminated by two null Unicode
                    characters, and within that sequence zero or more null-terminated Unicode strings can exist."
                    https://docs.microsoft.com/en-us/openspecs/windows_protocols/ms-gpreg/5c092c22-bf6b-4e7f-b180-b20743d368f5
                #>
                $valueDataNullTermJoin = $RP.ValueData -join $NullTerminator
                $dataBytes = [System.Text.Encoding]::Unicode.GetBytes($valueDataNullTermJoin + $NullTerminator + $NullTerminator)
                $dataSize = $dataBytes.Count
            }

        ([RegType]::REG_BINARY)
            {
                $dataBytes = [System.Text.Encoding]::Unicode.GetBytes($RP.ValueData)
                $dataSize = $dataBytes.Count
            }

        ([RegType]::REG_DWORD)
            {
                $dataBytes = [System.BitConverter]::GetBytes([Int32] ([string]$RP.ValueData))
                $dataSize = 4
            }

        ([RegType]::REG_QWORD)
            {
                $dataBytes = [System.BitConverter]::GetBytes([Int64]$RP.ValueData)
                $dataSize = 8
            }

        default
            {
                $dataBytes = [System.Text.Encoding]::Unicode.GetBytes("")
                $dataSize = 0
            }
    }

    $Entry += [System.BitConverter]::GetBytes($dataSize)

    $Entry += [System.Text.Encoding]::Unicode.GetBytes(';') # semicolon as delimiter

    $Entry += $dataBytes

    $Entry += [System.Text.Encoding]::Unicode.GetBytes(']') # Closing bracket

    return $Entry
}

<#
.SYNOPSIS
Appends an array of registry policy entries to a file.

.DESCRIPTION
Appends an array of registry policy entries to a file.

.PARAMETER RegistryPolicies
An array of registry policy entries.

.PARAMETER Path
Path to a file (.pol extension)
#>
Function Add-RegistryPolicies
{
    param (
		[Parameter(Mandatory = $true)]
        [GPRegistryPolicy[]]
        $RegistryPolicies,

		[Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Path
    )
        
    foreach ($rp in $RegistryPolicies)
    {
        [Byte[]] $Entry = New-RegistrySettingsEntry -RegistryPolicy $rp
        $Entry | Add-Content -Path $Path @byteParam
    }
}

Function Assert
{
    param (
        [Parameter(Mandatory = $true)]
        $Condition,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $ErrorMessage
    )

    if (!$Condition)
    {
        throw $ErrorMessage
    }
}

Function Convert-StringToInt
{
    [OutputType([System.Int32[]])]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.Object[]]
        $ValueString
    )
  
    if ($ValueString.Length -le 4)
    {
        [int32] $result = 0
    }
    elseif ($ValueString.Length -le 8)
    {
        [int64] $result = 0
    }
    else
    {
        throw "Invalid size for an integer. Must be less than or equal to 8."
    }

    for ($i = $ValueString.Length - 1 ; $i -ge 0 ; $i -= 1)
    {
        $result = $result -shl 8
        $result = $result + ([int][char]$ValueString[$i])
    }

    return $result
}

<#
    .SYNOPSIS
        Formats a multistring value.

    .DESCRIPTION
        Formats a multistring value by first spliting on \0 and the removing the terminating \0\0.
        This is need to match the desired valueData
#>
function Format-MultiStringValue
{
    [CmdletBinding()]
    [OutputType([System.String[]])]
    param
    (
        [Parameter()]
        [System.Object]
        $MultiStringValue
    )

    $result = @()
    if ($MultiStringValue -match $NullTerminator)
    {
        [System.Collections.ArrayList] $array = $MultiStringValue.TrimEnd($NullTerminator) -split $NullTerminator

        # Remove the terminating \0 from all indexes
        foreach ($item in $array)
        {
            $result += $item.TrimEnd($NullTerminator)
        }

        return $result
    }
    else
    {
        # If no terminating 0's are found split on whitespace
        return (-split $MultiStringValue)
    }
}

Export-ModuleMember -Function 'Read-PolFile','New-GPRegistryPolicyFile','Add-RegistryPolicies','New-RegistrySettingsEntry'
