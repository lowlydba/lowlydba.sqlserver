# Private
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Scope='Function', Justification='Using proper name of module imported.')]
param()
function Import-DbaTools {
    <#
        .SYNOPSIS
        Centralized way to import a standard minimum version across all modules in the collection.
    #>
    [CmdletBinding()]
    param(
        [System.Version]
        $MinimumVersion =   "1.1.40"
    )
    try {
        #Import-Module -Name "DbaTools" -MinimumVersion $MinimumVersion
    }
    catch {
        Write-Error -Message "Unable to install DbaTools v. $MinimumVersion. Try installing manually: Install-Module Dbatools -MinimumVersion $MinimumVersion -Force"
    }

}

Export-ModuleMember -Function "Import-DbaTools"
