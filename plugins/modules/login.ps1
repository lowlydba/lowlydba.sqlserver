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
        login = @{type = 'str'; required = $true }
        password = @{type = 'str'; required = $false; no_log = $true }
        status = @{type = 'str'; required = $false; default = 'enabled'; choices = @('enabled', 'disabled') }
        default_database = @{type = 'str'; required = $false }
        language = @{type = 'str'; required = $false }
        password_must_change = @{type = 'bool'; required = $false }
        password_policy_enforced = @{type = 'bool'; required = $false }
        password_expiration_enabled = @{type = 'bool'; required = $false }
        state = @{type = 'str'; required = $false; default = 'present'; choices = @('present', 'absent') }
    }
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec, @(Get-LowlyDbaSqlServerAuthSpec))
$sqlInstance, $sqlCredential = Get-SqlCredential -Module $module
$login = $module.Params.login
if ($null -ne $module.Params.password) {
    $secPassword = ConvertTo-SecureString -String $module.Params.password -AsPlainText -Force
}
$status = $module.Params.status
$defaultDatabase = $module.Params.default_database
$language = $module.Params.language
[nullable[bool]]$passwordMustChange = $module.Params.password_must_change
[nullable[bool]]$passwordExpirationEnabled = $module.Params.password_expiration_enforced
[nullable[bool]]$passwordPolicyEnforced = $module.Params.password_policy_enforced
$state = $module.Params.state
$checkMode = $module.CheckMode

$module.Result.changed = $false

try {
    $getLoginSplat = @{
        SqlInstance = $sqlInstance
        SqlCredential = $sqlCredential
        Login = $login
        ExcludeSystemLogin = $true
        EnableException = $true
    }
    $existingLogin = Get-DbaLogin @getLoginSplat

    if ($state -eq "absent") {
        if ($null -ne $existingLogin) {
            $output = $existingLogin | Remove-DbaLogin -WhatIf:$checkMode -EnableException -Force -Confirm:$false
            $module.Result.changed = $true
        }
    }
    elseif ($state -eq "present") {
        $setLoginSplat = @{
            SqlInstance = $sqlInstance
            SqlCredential = $sqlCredential
            Login = $login
            WhatIf = $checkMode
            EnableException = $true
            Confirm = $false
        }
        if ($null -ne $defaultDatabase) {
            $setLoginSplat.add("DefaultDatabase", $defaultDatabase)
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
        if ($null -ne $passwordMustChange) {
            $setLoginSplat.add("PasswordMustChange", $passwordMustChange)
        }

        # Login already exists
        if ($null -ne $existingLogin) {
            # Compare existing values with passed params, skipping over values not specified
            $keys = $setLoginSplat.Keys | Where-Object { $_ -ne 'SqlInstance' }
            $compareProperty = ($existingLogin.Properties | Where-Object Name -in $keys).Name
            $diff = Compare-Object -ReferenceObject $existingLogin -DifferenceObject $setLoginSplat -Property $compareProperty

            # Login needs to be modified
            if ($diff) {
                if ($status -eq "disabled") {
                    $setLoginSplat.add("Disable", $true)
                }
                else {
                    $setLoginSplat.add("Enable", $true)
                }
                $output = Set-DbaLogin @setLoginSplat
                $module.result.changed = $true
            }
        }
        # New login
        else {
            if ($null -ne $language) {
                $setLoginSplat.add("Language", $language)
            }
            if ($status -eq "disabled") {
                $setLoginSplat.add("Disabled", $true)
            }
            $output = New-DbaLogin @setLoginSplat
            $module.result.changed = $true
        }
        # If not in check mode, add extra fields we can change to default display set
        if ($null -ne $output) {
            $output.PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames.Add("DefaultDatabase")
            $output.PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames.Add("Language")
        }

    }

    if ($null -ne $output) {
        $resultData = ConvertTo-SerializableObject -InputObject $output
        $module.Result.data = $resultData
    }
    $module.ExitJson()
}
catch {
    $module.FailJson("Configuring login failed: $($_.Exception.Message) ; $setLoginSplat", $_)
}
