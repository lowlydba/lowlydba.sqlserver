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
        identity = @{type = 'str'; required = $true }
        name = @{type = 'str'; required = $false }
        secure_password = @{type = 'str'; required = $false }
        mapped_class_type = @{type = 'str'; required = $false; choices = @('present', 'absent') }
        provider_name = @{type = 'str'; required = $false }
        force = @{type = 'bool'; required = $false; default = $false }
        state = @{type = 'str'; required = $false; default = 'present'; choices = @('present', 'absent') }
    }
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec, @(Get-LowlyDbaSqlServerAuthSpec))
$sqlInstance, $sqlCredential = Get-SqlCredential -Module $module
$identity = $module.Params.identity
$name = $module.Params.name
$secure_password = $module.Params.secure_password
$mapped_class_type = $module.Params.mapped_class_type
$provider_name = $module.Params.provider_name
$state = $module.Params.state
$force = $module.Params.force
$checkMode = $module.CheckMode

$module.Result.changed = $false

$getCredendtialSplat = @{
    SqlInstance = $sqlInstance
    SqlCredential = $sqlCredential
    Identity = $identity
    EnableException = $true
}
$existingCredential = Get-DbaCredential @getCredendtialSplat

if ($state -eq "absent") {
    # Remove credential if it exists
    if ($null -ne $existingCredential) {
        try {
            $removeCredentialSplat = @{
                SqlInstance = $sqlInstance
                SqlCredential = $sqlCredential
                Identity = $identity
                EnableException = $true
                WhatIf = $checkMode
                Confirm = $false
            }
            $output = Remove-DbaCredential @removeCredentialSplat
            $module.Result.changed = $true
        }
        catch {
            $module.FailJson("Removing credential failed: $($_.Exception.Message)", $_)
        }
    }
}
elseif ($state -eq "present") {
    # Credential exists
    if ($null -ne $existingUser) {
        try {
            $newCredentialSplat = @{
                SqlInstance = $sqlInstance
                SqlCredential = $sqlCredential
                Identity = $identity
                EnableException = $true
                WhatIf = $checkMode
                Force = $force
                Confirm = $false
            }
            if ($null -ne $name) {
                $restoreSplat.Add("Name", $name)
            }
            if ($null -ne $secure_password) {
                $restoreSplat.Add("SecurePassword", $secure_password)
            }
            if ($null -ne $mapped_class_type) {
                $restoreSplat.Add("MappedClassType", $mapped_class_type)
            }
            if ($null -ne $provider_name) {
                $restoreSplat.Add("ProviderName", $provider_name)
            }
            $output = New-DbaDbCredential @newUserSplat
            $module.result.changed = $true
        }
        catch {
            $module.FailJson("Creating credential failed: $($_.Exception.Message)", $_)
        }
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