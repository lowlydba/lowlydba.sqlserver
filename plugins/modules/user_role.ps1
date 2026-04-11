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
        state = @{type = 'str'; required = $false; default = 'present'; choices = @('present', 'absent') }
    }
    mutually_exclusive = @(@('role', 'roles'), @('roles', 'state'))
    required_one_of = @(@('role', 'roles'))
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec, @(Get-LowlyDbaSqlServerAuthSpec))
$sqlInstance, $sqlCredential = Get-SqlCredential -Module $module

$username = $module.Params.username
$database = $module.Params.database
$roles = $module.Params.roles
$role = $module.Params.role
$state = $module.Params.state
$checkMode = $module.CheckMode

$module.Result.changed = $false

$commonParamSplat = @{
    SqlInstance = $sqlInstance
    SqlCredential = $sqlCredential
    Database = $database
    EnableException = $true
}

$outputProps = @{}
$addedRoles = @()
$removedRoles = @()

$getUserSplat = @{
    SqlInstance = $sqlInstance
    SqlCredential = $sqlCredential
    Database = $database
    User = $username
    EnableException = $true
}
$existingUser = Get-DbaDbUser @getUserSplat
if ($null -eq $existingUser) {
    $module.FailJson("User [$username] does not exist in database [$database].")
}

if ($null -ne $role) {
    $compatibilityMode = $true

    $getRoleSplat = @{
        SqlInstance = $sqlInstance
        SqlCredential = $sqlCredential
        Database = $database
        Role = $role
        EnableException = $true
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
                EnableException = $true
            }
            $existingRoleMembers = Get-DbaDbRoleMember @getRoleMemberSplat

            if ($existingRoleMembers.username -contains $username) {
                $removeRoleMemberSplat = @{
                    SqlInstance = $sqlInstance
                    SqlCredential = $sqlCredential
                    User = $username
                    Database = $database
                    Role = $role
                    EnableException = $true
                    WhatIf = $checkMode
                    Confirm = $false
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
                EnableException = $true
            }
            $existingRoleMembers = Get-DbaDbRoleMember @getRoleMemberSplat

            if ($existingRoleMembers.username -notcontains $username) {
                $addRoleMemberSplat = @{
                    SqlInstance = $sqlInstance
                    SqlCredential = $sqlCredential
                    User = $username
                    Database = $database
                    Role = $role
                    EnableException = $true
                    WhatIf = $checkMode
                    Confirm = $false
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
    $compatibilityMode = $false

    $rolesSetSpecified = $null -ne $roles['set']
    $rolesAddSpecified = $null -ne $roles['add']
    $rolesRemoveSpecified = $null -ne $roles['remove']

    $hasSet = $rolesSetSpecified -and @($roles['set']).Count -gt 0
    $hasAdd = $rolesAddSpecified -and @($roles['add']).Count -gt 0
    $hasRemove = $rolesRemoveSpecified -and @($roles['remove']).Count -gt 0

    if (-not ($hasSet -or $hasAdd -or $hasRemove) -and -not ($rolesSetSpecified -or $rolesAddSpecified -or $rolesRemoveSpecified)) {
        $module.FailJson("When using the 'roles' parameter, you must specify at least one of: roles.set, roles.add, or roles.remove.")
    }

    $queryMode = -not ($hasSet -or $hasAdd -or $hasRemove)

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
        $desiredRoles = [array]($roles['set'] | Sort-Object)
        $toAdd = Compare-Object -ReferenceObject $currentRoleMembership -DifferenceObject $desiredRoles | Where-Object { $_.SideIndicator -eq '=>' } | Select-Object -ExpandProperty InputObject
        $toRemove = Compare-Object -ReferenceObject $currentRoleMembership -DifferenceObject $desiredRoles | Where-Object { $_.SideIndicator -eq '<=' } | Select-Object -ExpandProperty InputObject

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
                        EnableException = $true
                        WhatIf = $checkMode
                        Confirm = $false
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
                        EnableException = $true
                        WhatIf = $checkMode
                        Confirm = $false
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
            $toAdd = Compare-Object -ReferenceObject $currentRoleMembership -DifferenceObject $roles['add'] | Where-Object { $_.SideIndicator -eq '=>' } | Select-Object -ExpandProperty InputObject

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
                            EnableException = $true
                            WhatIf = $checkMode
                            Confirm = $false
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
            $toRemove = Compare-Object -ReferenceObject $currentRoleMembership -DifferenceObject $roles['remove'] | Where-Object { $_.SideIndicator -eq '<=' } | Select-Object -ExpandProperty InputObject

            if ($toRemove.Count -gt 0) {
                foreach ($roleToRemove in $toRemove) {
                    try {
                        $removeRoleMemberSplat = @{
                            SqlInstance = $sqlInstance
                            SqlCredential = $sqlCredential
                            User = $username
                            Database = $database
                            Role = $roleToRemove
                            EnableException = $true
                            WhatIf = $checkMode
                            Confirm = $false
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