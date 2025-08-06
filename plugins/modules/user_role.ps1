#!powershell
# -*- coding: utf-8 -*-

# (c) 2022, John McCall (@lowlydba)
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -CSharpUtil Ansible.Basic
#AnsibleRequires -PowerShell ansible_collections.lowlydba.sqlserver.plugins.module_utils._SqlServerUtils
#Requires -Modules @{ ModuleName="dbatools"; ModuleVersion="2.0.0" }

$ErrorActionPreference = "Stop"

$spec = @{
    supports_check_mode = $true
    options = @{
        database = @{type = 'str'; required = $true }
        username = @{type = 'str'; required = $true }
        roles = @{type = 'list'; elements = 'str'; required = $true; aliases = 'role' }
        state = @{type = 'str'; required = $false; default = 'present'; choices = @('present', 'absent') }
        remove_unlisted = @{type = 'bool'; required = $false; default = 'false' }
    }
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec, @(Get-LowlyDbaSqlServerAuthSpec))
$sqlInstance, $sqlCredential = Get-SqlCredential -Module $module
$username = $module.Params.username
$database = $module.Params.database
$roles = $module.Params.roles
$state = $module.Params.state
$remove_unlisted = $module.Params.remove_unlisted
$checkMode = $module.CheckMode

$module.Result.changed = $false

$getUserSplat = @{
    SqlInstance = $sqlInstance
    SqlCredential = $sqlCredential
    Database = $database
    User = $username
    EnableException = $true
}

$outputProps = @{}

# Verify user and role(s) exist, DBATools currently fails silently
$existingUser = Get-DbaDbUser @getUserSplat
if ($null -eq $existingUser) {
    $module.FailJson("User [$username] does not exist in database [$database].")
}

$roles | ForEach-Object {
    $thisRole = $_
    $getRoleSplat = @{
        SqlInstance = $sqlInstance
        SqlCredential = $sqlCredential
        Database = $database
        Role = $thisrole
        EnableException = $true
    }
    $existingRole = Get-DbaDbRole @getRoleSplat
    if ($null -eq $existingRole) {
        $module.FailJson("Role [$thisRole] does not exist in database [$database].")
    }
}

# Get role members of all roles we care about to compare against later
$getRoleMemberSplat = @{
    SqlInstance = $sqlInstance
    SqlCredential = $sqlCredential
    Database = $database
    IncludeSystemUser = $true
    EnableException = $true
}
$existingRoleMembership = Get-DbaDbRoleMember @getRoleMemberSplat | Where-Object {$_.UserName -eq $username} | Select -ExpandProperty role | Sort-Object

if ($state -eq "absent") {
    $roles | ForEach-Object {
        $thisRole = $_
        if ( $existingRoleMembership -contains $thisRole ) {
            try {
                $removeRoleMemberSplat = @{
                    SqlInstance = $sqlInstance
                    SqlCredential = $sqlCredential
                    User = $username
                    Database = $database
                    Role = $thisRole
                    EnableException = $true
                    WhatIf = $checkMode
                    Confirm = $false
                }
                Remove-DbaDbRoleMember @removeRoleMemberSplat
                $module.Result.changed = $true
            }
            catch {
                $module.FailJson("Removing user [$username] from database role [$thisRole] failed: $($_.Exception.Message)", $_)
            }
        }
    }
}
elseif ($state -eq "present") {
    # Add user to role
    $roles | ForEach-Object {
        $thisRole = $_
        if ($existingRoleMembership -notcontains $thisRole) {
            try {
                $addRoleMemberSplat = @{
                    SqlInstance = $sqlInstance
                    SqlCredential = $sqlCredential
                    User = $username
                    Database = $database
                    Role = $thisRole
                    EnableException = $true
                    WhatIf = $checkMode
                    Confirm = $false
                }
                Add-DbaDbRoleMember @addRoleMemberSplat
                $module.Result.changed = $true
            }
            catch {
                $module.FailJson("Adding user [$username] to database role [$thisRole] failed: $($_.Exception.Message)", $_)
            }
        }
    }
}
if ($state -eq "present" -and $remove_unlisted -eq $true) {
    #remove users from roles that weren't listed (if we got the remove_unlisted option set to true)
    $existingRoleMembership | ForEach-Object {
        $thisRole = $_
        if ($roles -notcontains $thisRole) {
            try {
                $removeRoleMemberSplat = @{
                    SqlInstance = $sqlInstance
                    SqlCredential = $sqlCredential
                    User = $username
                    Database = $database
                    Role = $thisRole
                    EnableException = $true
                    WhatIf = $checkMode
                    Confirm = $false
                }
                Remove-DbaDbRoleMember @removeRoleMemberSplat
                $module.Result.changed = $true
            }
            catch {
                $module.FailJson("Removing user [$username] from extra unlisted database role [$thisRole] failed: $($_.Exception.Message)", $_)
            }
        }
    }
}

try {
    #after changing any roles above, see what our new membership is and report it back
    $newRoleMembership = Get-DbaDbRoleMember @getRoleMemberSplat | Where-Object {$_.UserName -eq $username} | Select -ExpandProperty role | Sort-Object
}
catch {
    $module.FailJson("Failure getting new role membership: $($_.Exception.Message)", $_)
}
$outputProps.newRoleMembership = [array]$newRoleMembership
$outputProps.oldRoleMembership = [array]$existingRoleMembership
$output = New-Object -TypeName PSCustomObject -Property $outputProps

try {
    if ($null -ne $output) {
        $resultData = ConvertTo-SerializableObject -InputObject $output
        $module.Result.data = $resultData
    }
    $module.ExitJson()
}
catch {
    $module.FailJson("Failure: $($_.Exception.Message)", $_)
}
