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
        roles = @{type = 'dict'; required = $false }
        role = @{type = 'str'; required = $false }
        state = @{type = 'str'; required = $false; choices = @('present', 'absent') }
    }
    mutually_exclusive = @(
        , @('role', 'roles')
    )
    required_one_of = @(
        , @('role', 'roles')
    )
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec, @(Get-LowlyDbaSqlServerAuthSpec))
$sqlInstance, $sqlCredential = Get-SqlCredential -Module $module

$username = $module.Params.username
$database = $module.Params.database
$roles = $module.Params.roles
$role = $module.Params.role
$state = $module.Params.state
$checkMode = $module.CheckMode

$PSDefaultParameterValues = @{ "*:EnableException" = $true; "*:Confirm" = $false; "*:WhatIf" = $checkMode }

if ($null -ne $roles -and $null -ne $state) {
    $msg = "The 'state' parameter is not supported when using the 'roles' parameter. "
    $msg += "Use roles.add, roles.remove, or roles.set to control membership changes."
    $module.FailJson($msg)
}

$module.Result.changed = $false

$commonParamSplat = @{
    SqlInstance = $sqlInstance
    SqlCredential = $sqlCredential
    Database = $database
}

$outputProps = @{}
$addedRoles = @()
$removedRoles = @()

$getUserSplat = @{
    SqlInstance = $sqlInstance
    SqlCredential = $sqlCredential
    Database = $database
    User = $username
}
$existingUser = Get-DbaDbUser @getUserSplat
if ($null -eq $existingUser) {
    $module.FailJson("User [$username] does not exist in database [$database].")
}

if ($null -ne $role) {
    # Set default state for legacy mode if not specified
    if ($null -eq $state) {
        $state = 'present'
    }

    $getRoleSplat = @{
        SqlInstance = $sqlInstance
        SqlCredential = $sqlCredential
        Database = $database
        Role = $role
    }
    $existingRole = Get-DbaDbRole @getRoleSplat
    if ($null -eq $existingRole) {
        $module.FailJson("Role [$role] does not exist in database [$database].")
    }

    if ($state -eq "absent") {
        try {
            $getRoleMemberSplat = @{
                SqlInstance = $sqlInstance
                SqlCredential = $sqlCredential
                Database = $database
                Role = $role
                IncludeSystemUser = $true
            }
            $existingRoleMembers = Get-DbaDbRoleMember @getRoleMemberSplat

            if ($existingRoleMembers.UserName -contains $username) {
                $removeRoleMemberSplat = @{
                    SqlInstance = $sqlInstance
                    SqlCredential = $sqlCredential
                    User = $username
                    Database = $database
                    Role = $role
                }
                $output = Remove-DbaDbRoleMember @removeRoleMemberSplat
                $module.Result.changed = $true
                if ($null -ne $output) {
                    $resultData = ConvertTo-SerializableObject -InputObject $output
                    $module.Result.data = $resultData
                }
            }
        }
        catch {
            $module.FailJson("Removing user [$username] from database role [$role] failed: $($_.Exception.Message)", $_)
        }
    }
    elseif ($state -eq "present") {
        try {
            $getRoleMemberSplat = @{
                SqlInstance = $sqlInstance
                SqlCredential = $sqlCredential
                Database = $database
                Role = $role
                IncludeSystemUser = $true
            }
            $existingRoleMembers = Get-DbaDbRoleMember @getRoleMemberSplat

            if ($existingRoleMembers.UserName -notcontains $username) {
                $addRoleMemberSplat = @{
                    SqlInstance = $sqlInstance
                    SqlCredential = $sqlCredential
                    User = $username
                    Database = $database
                    Role = $role
                }
                $output = Add-DbaDbRoleMember @addRoleMemberSplat
                $module.Result.changed = $true
                if ($null -ne $output) {
                    $resultData = ConvertTo-SerializableObject -InputObject $output
                    $module.Result.data = $resultData
                }
            }
        }
        catch {
            $module.FailJson("Adding user [$username] to database role [$role] failed: $($_.Exception.Message)", $_)
        }
    }
    $module.ExitJson()
}
else {
    $rolesSetSpecified = $null -ne $roles['set']
    $rolesAddSpecified = $null -ne $roles['add']
    $rolesRemoveSpecified = $null -ne $roles['remove']

    # Key presence determines intent; empty list is a valid explicit operation (e.g. set: [] removes all roles)
    $hasSet = $rolesSetSpecified
    $hasAdd = $rolesAddSpecified -and @($roles['add']).Count -gt 0
    $hasRemove = $rolesRemoveSpecified -and @($roles['remove']).Count -gt 0

    if (-not ($rolesSetSpecified -or $rolesAddSpecified -or $rolesRemoveSpecified)) {
        $module.FailJson("When using 'roles', at least one key (roles.set, roles.add, or roles.remove) must be present.")
    }

    if ($rolesSetSpecified -and ($rolesAddSpecified -or $rolesRemoveSpecified)) {
        $module.FailJson("The 'roles.set' option cannot be combined with 'roles.add' or 'roles.remove'.")
    }

    try {
        $membershipObjects = Get-DbaDbRoleMember @commonParamSplat -IncludeSystemUser $true | Where-Object { $_.UserName -eq $username }
        $currentRoleMembership = [array]($membershipObjects.Role | Sort-Object)
        if ($null -eq $currentRoleMembership) { $currentRoleMembership = @() }
    }
    catch {
        $module.FailJson("Failure getting current role membership: $($_.Exception.Message)", $_)
    }

    $desiredRoles = @()

    if ($hasSet) {
        $desiredRoles = @($roles['set'] | Sort-Object)
        if ($desiredRoles.Count -eq 0) {
            # set: [] — remove all current roles
            $toAdd = @()
            $toRemove = @($currentRoleMembership)
        }
        elseif ($currentRoleMembership.Count -eq 0) {
            # no current roles — add all desired
            $toAdd = @($desiredRoles)
            $toRemove = @()
        }
        else {
            $toAdd = Compare-Object -ReferenceObject $currentRoleMembership -DifferenceObject $desiredRoles |
                Where-Object { $_.SideIndicator -eq '=>' } | Select-Object -ExpandProperty InputObject
            $toRemove = Compare-Object -ReferenceObject $currentRoleMembership -DifferenceObject $desiredRoles |
                Where-Object { $_.SideIndicator -eq '<=' } | Select-Object -ExpandProperty InputObject
        }

        if ($toAdd.Count -gt 0) {
            foreach ($roleToAdd in $toAdd) {
                $existingRole = Get-DbaDbRole @commonParamSplat -Role $roleToAdd
                if ($null -eq $existingRole) {
                    $module.FailJson("Role [$roleToAdd] does not exist in database [$database].")
                }

                try {
                    $addRoleMemberSplat = @{
                        SqlInstance = $sqlInstance
                        SqlCredential = $sqlCredential
                        User = $username
                        Database = $database
                        Role = $roleToAdd
                    }
                    Add-DbaDbRoleMember @addRoleMemberSplat
                    $addedRoles += $roleToAdd
                    $module.Result.changed = $true
                }
                catch {
                    $module.FailJson("Adding user [$username] to database role [$roleToAdd] failed: $($_.Exception.Message)", $_)
                }
            }
        }

        if ($toRemove.Count -gt 0) {
            foreach ($roleToRemove in $toRemove) {
                try {
                    $removeRoleMemberSplat = @{
                        SqlInstance = $sqlInstance
                        SqlCredential = $sqlCredential
                        User = $username
                        Database = $database
                        Role = $roleToRemove
                    }
                    Remove-DbaDbRoleMember @removeRoleMemberSplat
                    $removedRoles += $roleToRemove
                    $module.Result.changed = $true
                }
                catch {
                    $module.FailJson("Removing user [$username] from database role [$roleToRemove] failed: $($_.Exception.Message)", $_)
                }
            }
        }

        try {
            $membershipObjects = Get-DbaDbRoleMember @commonParamSplat -IncludeSystemUser $true | Where-Object { $_.UserName -eq $username }
            $currentRoleMembership = [array]($membershipObjects.Role | Sort-Object)
            if ($null -eq $currentRoleMembership) { $currentRoleMembership = @() }
        }
        catch {
            $module.FailJson("Failure getting current role membership: $($_.Exception.Message)", $_)
        }
    }
    else {
        if ($hasAdd) {
            $desiredRoles += $roles['add']
        }
        if ($hasRemove) {
            $desiredRoles += $roles['remove']
        }
        $desiredRoles = [array]($desiredRoles | Sort-Object -Unique)

        if ($hasAdd) {
            $toAdd = Compare-Object -ReferenceObject $currentRoleMembership -DifferenceObject $roles['add'] |
                Where-Object { $_.SideIndicator -eq '=>' } | Select-Object -ExpandProperty InputObject

            if ($toAdd.Count -gt 0) {
                foreach ($roleToAdd in $toAdd) {
                    $existingRole = Get-DbaDbRole @commonParamSplat -Role $roleToAdd
                    if ($null -eq $existingRole) {
                        $module.FailJson("Role [$roleToAdd] does not exist in database [$database].")
                    }

                    try {
                        $addRoleMemberSplat = @{
                            SqlInstance = $sqlInstance
                            SqlCredential = $sqlCredential
                            User = $username
                            Database = $database
                            Role = $roleToAdd
                        }
                        Add-DbaDbRoleMember @addRoleMemberSplat
                        $addedRoles += $roleToAdd
                        $module.Result.changed = $true
                    }
                    catch {
                        $module.FailJson("Adding user [$username] to database role [$roleToAdd] failed: $($_.Exception.Message)", $_)
                    }
                }
            }
        }

        if ($hasRemove) {
            $toRemove = @($roles['remove'] | Where-Object { $_ -in $currentRoleMembership })

            if ($toRemove.Count -gt 0) {
                foreach ($roleToRemove in $toRemove) {
                    try {
                        $removeRoleMemberSplat = @{
                            SqlInstance = $sqlInstance
                            SqlCredential = $sqlCredential
                            User = $username
                            Database = $database
                            Role = $roleToRemove
                        }
                        Remove-DbaDbRoleMember @removeRoleMemberSplat
                        $removedRoles += $roleToRemove
                        $module.Result.changed = $true
                    }
                    catch {
                        $module.FailJson("Removing user [$username] from database role [$roleToRemove] failed: $($_.Exception.Message)", $_)
                    }
                }
            }
        }

        try {
            $membershipObjects = Get-DbaDbRoleMember @commonParamSplat -IncludeSystemUser $true | Where-Object { $_.UserName -eq $username }
            $currentRoleMembership = [array]($membershipObjects.Role | Sort-Object)
            if ($null -eq $currentRoleMembership) { $currentRoleMembership = @() }
        }
        catch {
            $module.FailJson("Failure getting current role membership: $($_.Exception.Message)", $_)
        }
    }

    $outputProps['roleMembership'] = $currentRoleMembership
    if ($addedRoles.Count -gt 0) { $outputProps['added'] = $addedRoles }
    if ($removedRoles.Count -gt 0) { $outputProps['removed'] = $removedRoles }

    $output = New-Object -TypeName PSCustomObject -Property $outputProps

    $resultData = ConvertTo-SerializableObject -InputObject $output
    $module.Result.data = $resultData

    $module.ExitJson()
}
