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
        database = @{ type = 'str'; required = $true }
        username = @{ type = 'str'; required = $true }
        state = @{ type = 'str'; required = $false; default = 'present'; choices = @('present', 'absent') }
        role = @{ type = 'str'; required = $false }
        roles = @{
            default = @{}
            type = 'dict'
            options = @{
                add = @{
                    default = @()
                    type = 'list'
                    elements = 'str'
                }
                remove = @{
                    default = @()
                    type = 'list'
                    elements = 'str'
                }
                set = @{
                    default = $null
                    type = 'list'
                    elements = 'str'
                }
            }
        }
    }
    required_one_of = @(
        , @("role", "roles")
    )
    mutually_exclusive = @(
        , @("role", "roles")
    )
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec, @(Get-LowlyDbaSqlServerAuthSpec))
$sqlInstance, $sqlCredential = Get-SqlCredential -Module $module
$username = $module.Params.username
$database = $module.Params.database
$role = $module.Params.role
$roles = $module.Params.roles
$state = $module.Params.state
$checkMode = $module.CheckMode
$compatibilityMode = $false

$module.Result.changed = $false

# Map the "old" style way of using state and role on to the add/remove/set methods
if ($role -and $state -eq 'present') {
    $roles.add = @(, $role)
    $compatibilityMode = $true
}
if ($role -and $state -eq 'absent') {
    $roles.remove = @(, $role)
    $compatibilityMode = $true
}

$commonParamSplat = @{
    SqlInstance = $sqlInstance
    SqlCredential = $sqlCredential
    Database = $database
    EnableException = $true
}

$outputProps = @{}

# Verify user and role(s) exist, DBATools currently fails silently
$existingUser = Get-DbaDbUser @commonParamSplat -user $username
if ($null -eq $existingUser) {
    $module.FailJson("User [$username] does not exist in database [$database].")
}

$combinedRoles = ( $roles['set'] + $roles['add'] + $roles['remove'] ) | Select-Object -Unique
$combinedRoles | ForEach-Object {
    $thisRole = $_
    $existingRole = Get-DbaDbRole @commonParamSplat -role $thisRole
    if ($null -eq $existingRole) {
        $module.FailJson("Role [$thisRole] does not exist in database [$database].")
    }
}

# Sanity check on the add/remove clause not having the same role.
$sameRoles = ( Compare-Object $roles['add'] $roles['remove'] -IncludeEqual | Where-Object { $_.SideIndicator -eq '==' } ).InputObject
if ($sameRoles.count -ge 1) {
    $module.FailJson("Role [$($sameRoles -join ', ')] exists in both the add and remove lists.")
}

# Get current role membership of all roles for the user to compare against
$membershipObjects = Get-DbaDbRoleMember @commonParamSplat -IncludeSystemUser $true | Where-Object { $_.UserName -eq $username }
$existingRoleMembership = [array]($membershipObjects.role | Sort-Object)

if ($null -eq $existingRoleMembership) { $existingRoleMembership = @() }

if ($null -ne $roles['set']) {
    $comparison = Compare-Object $existingRoleMembership ([array]$roles['set'])
    $rolesToAdd = ( $comparison | Where-Object { $_.SideIndicator -eq '=>' } ).InputObject
    $rolesToRemove = ( $comparison | Where-Object { $_.SideIndicator -eq '<=' } ).InputObject
}
else {
    $rolesToAdd = ( Compare-Object $existingRoleMembership ([array]$roles['add']) | Where-Object { $_.SideIndicator -eq '=>' } ).InputObject
    $rolesToRemove = ( Compare-Object $existingRoleMembership ([array]$roles['remove']) -IncludeEqual | Where-Object { $_.SideIndicator -eq '==' } ).InputObject
}

# Add user to new roles
foreach ($thisRole in $rolesToAdd) {
    try {
        $addRoleMemberSplat = @{
            User = $username
            Role = $thisRole
            WhatIf = $checkMode
            Confirm = $false
        }
        $commandResult = Add-DbaDbRoleMember @commonParamSplat @addRoleMemberSplat
        $module.Result.changed = $true
    }
    catch {
        $module.FailJson("Adding user [$username] to database role [$thisRole] failed: $($_.Exception.Message)", $_)
    }
}

# remove user from unneeded roles
foreach ($thisRole in $rolesToRemove) {
    try {
        $removeRoleMemberSplat = @{
            User = $username
            Role = $thisRole
            WhatIf = $checkMode
            Confirm = $false
        }
        $commandResult = Remove-DbaDbRoleMember @commonParamSplat @removeRoleMemberSplat
        $module.Result.changed = $true
    }
    catch {
        $module.FailJson("Removing user [$username] from database role [$thisRole] failed: $($_.Exception.Message)", $_)
    }
}

# if we're still using old mode (using $state and $role) save command result as results,
# otherwise send back full list of old and new roles.
if ($compatibilityMode) {
    $output = $commandResult
}
else {
    try {
        # after changing any roles above, see what our new membership is and report it back
        $membershipObjects = Get-DbaDbRoleMember @commonParamSplat -IncludeSystemUser $true | Where-Object { $_.UserName -eq $username }
        $newRoleMembership = [array]($membershipObjects.role | Sort-Object)
    }
    catch {
        $module.FailJson("Failure getting new role membership: $($_.Exception.Message)", $_)
    }
    $outputProps.roleMembership = $newRoleMembership
    if ($module.Result.changed) {
        $outputProps.diff = @{}
        $outputProps.diff.after = $newRoleMembership
        $outputProps.diff.before = $existingRoleMembership
    }
    $output = New-Object -TypeName PSCustomObject -Property $outputProps
}

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
