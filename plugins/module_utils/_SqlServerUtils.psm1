# -*- coding: utf-8 -*-

# (c) 2022, John McCall (@lowlydba)
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

# Private

function Get-LowlyDbaSqlServerAuthSpec {
    <#
        .SYNOPSIS
        Output the auth spec used by every module.

        .DESCRIPTION
        Standardized way to access the common auth spec for modules.
        Uses the recommended Ansible naming convention.
    #>
    @(
        @{
            options = @{
                sql_instance = @{type = 'str'; required = $true }
                sql_username = @{type = 'str'; required = $false }
                sql_password = @{type = 'str'; required = $false; no_log = $true }
            }
            required_together = @(@('sql_username', 'sql_password'))
        }
    )
}

function Get-SqlCredential {
    <#
        .SYNOPSIS
        Build a credential object for SQL Authentication.

        .DESCRIPTION
        Standardized way to build a SQL Credential object that is required for SQL Authentication.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateScript({ $_.GetType().FullName -eq 'Ansible.Basic.AnsibleModule' })]
        $Module
    )
    try {
        $sqlInstance = $Module.Params.sql_instance
        if ($null -ne $Module.Params.sql_username) {
            [securestring]$secPassword = ConvertTo-SecureString $Module.Params.sql_password -AsPlainText -Force
            [pscredential]$sqlCredential = New-Object System.Management.Automation.PSCredential ($Module.Params.sql_username, $secPassword)
        }
        else {
            $sqlCredential = $null
        }
        return $sqlInstance, $sqlCredential
    }
    catch {
        Write-Error ("Error building Credential for SQL Authentication spec.")
    }
}

function ConvertTo-SerializableObject {
    <#
        .SYNOPSIS
        Transforms objects to a serialization-friendly structure, safe for Linux and Windows.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [Object]$InputObject,
        [Parameter()]
        [string[]]$ExcludeProperty = @(
            'Properties', 'Urn', 'ExecutionManager', 'UserData', 'ParentCollection',
            'DatabaseEngineEdition', 'DatabaseEngineType', 'ServerVersion', 'Server', 'Parent'
        ),
        [bool]$UseDefaultProperty = $true
    )

    Begin {
        if (-not $IsLinux) {
            Remove-TypeData -TypeName System.Array -ErrorAction SilentlyContinue
        }
    }

    Process {
        if ($null -eq $InputObject) { return $null }

        # Handle collections recursively
        if ($InputObject -is [System.Collections.IEnumerable] -and -not ($InputObject -is [string])) {
            $results = @()
            foreach ($item in $InputObject) {
                $results += ConvertTo-SerializableObject -InputObject $item -ExcludeProperty $ExcludeProperty -UseDefaultProperty:$UseDefaultProperty
            }
            return $results
        }

        # Determine default display properties
        try {
            $defaultProperty = $null
            if ($InputObject -and $InputObject.PSStandardMembers -and $InputObject.PSStandardMembers.DefaultDisplayPropertySet) {
                $defaultProperty = $InputObject.PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames
            }
        }
        catch {
            $defaultProperty = $null
        }

        if ($defaultProperty -and $UseDefaultProperty) {
            $objectProperty = $InputObject.PSObject.Properties | Where-Object { $_.Name -in $defaultProperty -and $_.Name -notin $ExcludeProperty }
        }
        else {
            $objectProperty = $InputObject.PSObject.Properties | Where-Object { $_.Name -notin $ExcludeProperty }
        }

        # Build a sanitized property list
        $properties = foreach ($p in $objectProperty) {
            $pName = $p.Name
            $pValue = $p.Value

            switch ($p) {
                { $null -eq $pValue } {
                    @{ Name = $pName; Expression = { $null }.GetNewClosure() }
                    break
                }
                { $pValue -is [datetime] } {
                    @{ Name = $pName; Expression = { $pValue.ToString('o') }.GetNewClosure() }
                    break
                }
                { $pValue -is [enum] -or $pValue -is [type] } {
                    @{ Name = $pName; Expression = { $pValue.ToString() }.GetNewClosure() }
                    break
                }
                { $null -ne $pValue -and $pValue.GetType().Name -like '*Collection' } {
                    @{ Name = $pName; Expression = { [string[]]($pValue.Name) }.GetNewClosure() }
                    break
                }
                { $null -ne $pValue -and $pValue.GetType().Name -eq 'User' } {
                    @{ Name = $pName; Expression = { [string[]]($pValue.Name) }.GetNewClosure() }
                    break
                }
                { $null -ne $pValue -and -not ($pValue -is [string] -or $pValue -is [int] -or $pValue -is [bool] -or $pValue -is [double]) } {
                    @{ Name = $pName; Expression = {
                        try {
                            # Check by type name, do not reference [SystemPolicy] directly
                            if ($pValue.GetType().Name -eq 'SystemPolicy') {
                                return [PSCustomObject]@{ Value = $pValue.ToString() }
                            }

                            # Safely check for nested SystemPolicy property
                            $sysPolicyProp = $pValue.PSObject?.Properties.Match('SystemPolicy')
                            if ($sysPolicyProp -and $sysPolicyProp.Count -gt 0) {
                                return [PSCustomObject]@{ Value = ($sysPolicyProp[0].Value.ToString()) }
                            }

                            # Fall back to Name property if exists
                            $nameProp = $pValue.PSObject?.Properties.Match('Name')
                            if ($nameProp -and $nameProp.Count -gt 0) {
                                return $nameProp[0].Value
                            }

                            return $pValue.ToString()
                        }
                        catch {
                            return $pValue.ToString()
                        }
                    }.GetNewClosure() }
                    break
                }
                default { $pName }
            }
        }

        try {
            $result = $InputObject | Select-Object -Property $properties
            return [PSCustomObject]$result
        }
        catch {
            $ht = @{}
            foreach ($p in $objectProperty) {
                try { $ht[$p.Name] = $p.Value } catch { $ht[$p.Name] = $p.Value.ToString() }
            }
            return [PSCustomObject]$ht
        }
    }
}

$exportMembers = @("Get-SqlCredential", "ConvertTo-SerializableObject", "Get-LowlyDbaSqlServerAuthSpec")
Export-ModuleMember -Function $exportMembers
