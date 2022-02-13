# Private
#[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Scope = 'Function', Justification = 'Using proper name of module imported.')]
#param()
function Import-ModuleDependency {
    <#
        .SYNOPSIS
        Centralized way to import a standard minimum version across all modules in the collection.
    #>
    [CmdletBinding()]
    param(
        [System.Version]
        $MinimumVersion = "1.1.40"
    )
    try {
        Import-Module -Name "DbaTools" -MinimumVersion $MinimumVersion -DisableNameChecking
    }
    catch {
        Write-Warning -Message "Unable to import DbaTools >= $MinimumVersion."
    }
}
function ConvertTo-HashTable {
    <#
        .SYNOPSIS
        Centralized way to convert DBATools' returned objects into hash tables.
    #>
    [CmdletBinding()]
    param(
        [PSCustomObject]
        $Object
    )
    try {
        $outputHash = @{}
        [string[]] $defaultDisplayProperty = $Object.PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames
        $objectProperty = ($Object | Select-Object -Property $defaultDisplayProperty).PSObject.Properties
        foreach ($property in $objectProperty) {
            $propertyName = $property.Name
            switch -Wildcard ($property.TypeNameOfValue) {
                "Microsoft*Collection" { $outputHash[$propertyName] = [string[]]$Object.$propertyName.Name }
                "Microsoft*" { $outputHash[$propertyName] = $Object.$propertyName.Name }
                "SqlCollaborative.DbaTools.Parameter.DbaInstanceParameter" { $outputHash[$propertyName] = $Object.$propertyName.FullName }
                default { $outputHash[$propertyName] = $Object.$propertyName }
            }
        }
        return $outputHash
    }
    catch {
        Write-Error -Message "Unable to convert object to hash table: $($_.Exception.Message)" -TargetObject $Object
    }
}

Export-ModuleMember -Function @("Import-ModuleDependency", "ConvertTo-HashTable")
