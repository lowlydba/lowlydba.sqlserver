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
        login = @{type = 'str'; required = $true }
        database = @{type = 'str'; required = $true }
        username = @{type = 'str'; required = $true }
        default_schema = @{type = 'str'; required = $false ; default = 'dbo' }
        external_provider = @{type = 'bool'; required = $false }
        state = @{type = 'str'; required = $false; default = 'present'; choices = @('present', 'absent') }
    }
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec, @(Get-LowlyDbaSqlServerAuthSpec))
$sqlInstance, $sqlCredential = Get-SqlCredential -Module $module
$login = $module.Params.login
$username = $module.Params.username
$database = $module.Params.database
$defaultSchema = $module.Params.default_schema
[nullable[bool]]$externalProvider = $module.Params.external_provider
$state = $module.Params.state
$checkMode = $module.CheckMode

$module.Result.changed = $false

try {
    $getUserSplat = @{
        SqlInstance = $sqlInstance
        SqlCredential = $sqlCredential
        User = $username
        Login = $login
        Database = $database
        EnableException = $true
    }
    $existingUser = Get-DbaDbUser @getUserSplat

    if ($state -eq "absent") {
        if ($null -ne $existingUser) {
            $output = $existingUser | Remove-DbaDbUser -WhatIf:$checkMode -EnableException -Force -Confirm:$false
            $module.Result.changed = $true
        }
    }
    elseif ($state -eq "present") {
        # User exists
        if ($null -ne $existingUser) {
            if ($defaultSchema -ne $existingUser.DefaultSchema) {
                # No Set-DbaDbUser command exists, use SMO
                $getSchemaSplat = @{
                    SqlInstance = $sqlInstance
                    SqlCredential = $sqlCredential
                    Database = $database
                    Schema = $defaultSchema
                    EnableException = $true
                }
                $existingSchema = Get-DbaDbSchema $getSchemaSplat

                if ($null -ne $existingSchema) {
                    # do schema change
                    if (-not($checkMode)) {
                        $existingUser.DefaultSchema = $defaultSchema
                        $existingUser.Alter()
                        $output = $existingUser
                    }
                    $module.result.changed = $true
                }
                else {
                    $module.FailJson("Schema '$defaultSchema' not found in [$database].")
                }
            }
        }
        # New User
        else {
            $newUserSplat = @{
                SqlInstance = $sqlInstance
                SqlCredential = $sqlCredential
                Username = $username
                Login = $login
                Database = $database
                DefaultSchema = $defaultSchema
                EnableException = $true
                WhatIf = $checkMode
                Force = $true
                Confirm = $false
            }
            if ($externalProvider -eq $true) {
                $newUserSplat.add("ExternalProvider", $true)
            }
            $output = New-DbaDbUser @newUserSplat
            $module.result.changed = $true
        }
        # If not in check mode, add extra fields we can change to default display set
        if ($null -ne $output) {
            $output.PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames.Add("DefaultSchema")
        }
    }

    if ($null -ne $output) {
        $resultData = ConvertTo-SerializableObject -InputObject $output
        $module.Result.data = $resultData
    }
    $module.ExitJson()
}
catch {
    $module.FailJson("Configuring user failed: $($_.Exception.Message)", $_)
}
