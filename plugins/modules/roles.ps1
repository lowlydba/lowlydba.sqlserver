#!powershell
# -*- coding: utf-8 -*-

# (c) 2022, John McCall (@lowlydba)
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -CSharpUtil Ansible.Basic
#AnsibleRequires -PowerShell ansible_collections.lowlydba.sqlserver.plugins.module_utils._SqlServerUtils
#Requires -Modules @{ ModuleName="dbatools"; ModuleVersion="1.1.112" }

$ErrorActionPreference = "Stop"

$spec = @{
    supports_check_mode = $true
    options = @{
        database = @{type = 'str'; required = $true }
        username = @{type = 'str'; required = $true }
        roles = @{type = 'list'; elements = 'str'; required = $true }
        state = @{type = 'str'; required = $false; default = 'present'; choices = @('present', 'absent') }
    }
}


$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec, @(Get-LowlyDbaSqlServerAuthSpec))
$sqlInstance, $sqlCredential = Get-SqlCredential -Module $module
$username = $module.Params.username
$database = $module.Params.database
$roles = $module.Params.roles
$state = $module.Params.state
$checkMode = $module.CheckMode

$module.Result.changed = $false

$getRoleSplat = @{
    SqlInstance = $sqlInstance
    SqlCredential = $sqlCredential
    Database = $database
    EnableException = $true
}
$module.Result.roles = $roles
$existingRoleObjects = Get-DbaDbRoleMember @getRoleSplat | Where-Object { $_.UserName -eq $username }
$roleObjectOutput = @{}
$i = 0
foreach ($object in $existingRoleObjects) {
    $roleObjectOutput.Add("$($object.UserName)_($i)", $object.Role)
    $i++
}
$module.Result.existingRoleObjects = $roleObjectOutput

if ($state -eq "absent") {
    # loop through all roles to remove and see if they are assigned to the user
    $removeRoles = @()
    foreach ($roleObject in $existingRoleObjects) {
        if ($roles.Contains($roleObject.role)) {
            $removeRoles += $roleObject.role
        }
    }

    $module.Result.removeRoles = $removeRoles
    if ($removeRoles) {
        try {
            $removeRolesSplat = @{
                SqlInstance = $sqlInstance
                SqlCredential = $sqlCredential
                User = $username
                Database = $database
                Role = $removeRoles -join ","
                EnableException = $true
                WhatIf = $checkMode
                Confirm = $false
                Verbose = $true
            }
            $output = Remove-DbaDbRoleMember @removeRolesSplat
            $module.Result.changed = $true
        }
        catch {
            $module.FailJson("Removing role failed: $($_.Exception.Message)", $_)
        }
    }
    else {
        $output = $existingRoleObjects
    }
}
elseif ($state -eq "present") {
    $existingRoles = @()
    # build an array of roles for the selected user
    foreach ($roleObject in $existingRoleObjects) {
        $existingRoles += $roleObject.role
    }
    # compare the list of roles to add vs the existing roles for the user and get the difference
    $addRoles = $roles | Where-Object { $existingRoles -NotContains $_ }
    $module.Result.addRoles = $addRoles
    if ($null -ne $addRoles) {
        try {
            # No Set-DbaDbUser command exists, use SMO
            $addRolesSplat = @{
                SqlInstance = $sqlInstance
                SqlCredential = $sqlCredential
                User = $username
                Database = $database
                Role = $addRoles -join ","
                EnableException = $true
                WhatIf = $checkMode
                Confirm = $false
                Verbose = $true
            }
            $output = Add-DbaDbRoleMember @addRolesSplat
            $module.Result.changed = $true
        }
        catch {
            $module.FailJson("Adding role failed: $($_.Exception.Message)", $_)
        }
    }
    else {
        $output = $existingRoleObjects
    }
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
