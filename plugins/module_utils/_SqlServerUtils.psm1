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

Export-ModuleMember -Function "Import-ModuleDependency"
