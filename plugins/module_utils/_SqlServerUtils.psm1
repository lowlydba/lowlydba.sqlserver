# Private
function Import-ModuleDependency {
    <#
        .SYNOPSIS
        Centralized way to import a standard minimum version across all modules in the collection.
    #>
    [CmdletBinding()]
    param(
        [System.Version]
        $MinimumVersion = "1.1.74"
    )
    try {
        Import-Module -Name "DbaTools" -MinimumVersion $MinimumVersion -DisableNameChecking
    }
    catch {
        Write-Warning -Message "Unable to import DbaTools >= $MinimumVersion."
    }
}

function ConvertTo-SerializableObject {
    <#
        .SYNOPSIS
        Transforms some members of a DbaTools result objects to be more serialization-friendly and prevent infinite recursion.

        .DESCRIPTION
        Stringifies version properties so we don't get serialized [System.Version] objects which aren't very useful.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [Object]
        $InputObject,
        [Parameter()]
        [string[]]
        $ExcludeProperty = @(
            <#
                Returning a list of properties as a property is redundant.
            #>
            'Properties',
            <#
                Urn is not useful.
            #>
            'Urn',
            <#
                ExecutionManager can contain a login password in plain text.
            #>
            'ExecutionManager',
            <#
                UserData is not useful.
            #>
            'UserData',
            <#
                ParentCollection is redundant.
            #>
            'ParentCollection',
            <#
                DatabaseEngineEdition is not useful.
            #>
            'DatabaseEngineEdition',
            <#
                DatabaseEngineType is not useful.
            #>
            'DatabaseEngineType',
            <#
                ServerVersion is not useful.
            #>
            'ServerVersion',
            <#
                Parent is not useful.
            #>
            'Parent'
        )
    )

    Process {
        $defaultProperty = $InputObject.PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames
        $objectProperty = $InputObject.PSObject.Properties | Where-Object { $_.Name -in $defaultProperty -and $_.Name -notin $ExcludeProperty }
        $properties = foreach ($p in $objectProperty) {
            $pName = $p.Name
            $pValue = $p.Value

            switch ($p) {
                {$pValue -is [datetime] } {
                    @{
                        Name = $pName
                        Expression = { $pValue.ToString('o') }.GetNewClosure()
                    }
                    break
                }
                {$pValue -is [enum] -or $_ -is [type]} {
                    @{
                        Name = $pName
                        Expression = { $pValue.ToString() }.GetNewClosure()
                    }
                    break
                }
                {$pValue -is [Microsoft.SqlServer.Management.Smo.SimpleObjectCollectionBase]} {
                    @{
                        Name = $pName
                        Expression = { [string[]]($pValue.Name) }.GetNewClosure()
                    }
                    break
                }
                default { $pName}
            }
        }
        return $InputObject | Select-Object -Property $properties
    }
}

Export-ModuleMember -Function @("Import-ModuleDependency", "ConvertTo-SerializableObject")
