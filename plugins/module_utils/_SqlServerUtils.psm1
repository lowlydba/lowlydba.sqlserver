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

function Format-JsonOutput {
    <#
        .SYNOPSIS
        Centralized way to convert DBATools' returned objects into json output.
    #>
    [CmdletBinding()]
    param(
        [PSCustomObject]
        $Object
    )
    try {
        # SMO properties that aren't useful or may contain secrets
        $excludeProperty = @("Properties", "Urn", "ExecutionManager", "UserData")
        # If present, only use default property set
        $defaultPropertySet = $Object.PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames

        $output = $Object | Select-Object -Property $defaultPropertySet -ExcludeProperty $excludeProperty | ConvertTo-Json -Depth 0 -EnumsAsStrings
        return $output
    }
    catch {
        Write-Error -Message "Unable to convert object to JSON: $($_.Exception.Message)" -TargetObject $Object
    }
}

Export-ModuleMember -Function @("Import-ModuleDependency", "Format-JsonOutput")
