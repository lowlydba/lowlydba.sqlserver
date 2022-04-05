#!powershell
# -*- coding: utf-8 -*-

# (c) 2022, John McCall (@lowlydba)
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -CSharpUtil Ansible.Basic
#AnsibleRequires -PowerShell ansible_collections.lowlydba.sqlserver.plugins.module_utils._SqlServerUtils
#Requires -Modules @{ ModuleName="dbatools"; ModuleVersion="1.1.83" }

$ErrorActionPreference = "Stop"

$spec = @{
    supports_check_mode = $true
    options = @{
        new_name = @{type = 'str'; required = $false; }
        password = @{type = 'str'; required = $false; no_log = $true }
        status = @{type = 'str'; required = $false; default = 'enabled'; choices = @('enabled', 'disabled') }
        password_must_change = @{type = 'bool'; required = $false }
        password_policy_enforced = @{type = 'bool'; required = $false }
        password_expiration_enabled = @{type = 'bool'; required = $false }
    }
}
$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec, @(Get-LowlyDbaSqlServerAuthSpec))
$sqlInstance, $sqlCredential = Get-SqlCredential -Module $module
$newName = $module.Params.new_name
if ($null -ne $module.Params.password) {
    $secPassword = ConvertTo-SecureString -String $module.Params.password -AsPlainText -Force
}
$status = $module.Params.status
[nullable[bool]]$passwordMustChange = $module.Params.password_must_change
[nullable[bool]]$passwordExpirationEnabled = $module.Params.password_expiration_enforced
[nullable[bool]]$passwordPolicyEnforced = $module.Params.password_policy_enforced
$checkMode = $module.CheckMode
$module.Result.changed = $false

try {
    $sa = Get-DbaLogin -SqlInstance $SqlInstance -SqlCredential $sqlCredential | Where-Object ID -eq 1

    $setLoginSplat = @{ }

    if ($newName) {
        $setLoginSplat.Add("NewName", $newName)
    }
    if ($null -ne $passwordExpirationEnforced) {
        $setLoginSplat.add("PasswordExpirationEnabled", $passwordExpirationEnabled)
    }
    if ($null -ne $passwordPolicyEnforced) {
        $setLoginSplat.add("PasswordPolicyEnforced", $passwordPolicyEnforced)
    }
    if ($null -ne $secPassword) {
        $setLoginSplat.add("SecurePassword", $secPassword)
    }
    if ($true -eq $passwordMustChange) {
        $setLoginSplat.add("PasswordMustChange", $passwordMustChange)
    }
    if ($status -eq "disabled") {
        $disabled = $true
        $setLoginSplat.add("Disable", $true)
    }
    else {
        $setLoginSplat.add("Enable", $true)
    }

    # Check for changes
    $keys = $setLoginSplat.Keys | Where-Object { $_ -ne 'SqlInstance' }
    $compareProperty = ($sa.Properties | Where-Object Name -in $keys).Name
    $diff = Compare-Object -ReferenceObject $sa -DifferenceObject $setLoginSplat -Property $compareProperty

    if (($null -ne $diff) -or ($sa.IsDisabled -ne $disabled)) {
        $output = $sa | Set-DbaLogin @setLoginSplat -WhatIf:$checkMode -EnableException
        $module.Result.changed = $true
    }
    else {
        $output = $sa
    }

    if ($null -ne $output) {
        $module.Result.test = $true
        $resultData = ConvertTo-SerializableObject -InputObject $output
        $module.Result.data = $resultData
    }
    $module.exitJson()
}
catch {
    $module.FailJson("Configuring 'sa' login failed: $($_.Exception.Message)", $_)
}
