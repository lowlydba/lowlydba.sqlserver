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
        database = @{type = 'str'; required = $false }
        username = @{type = 'str'; required = $false }
        roles = @{type = 'list'; elements = 'str'; required = $false }
    }
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec, @(Get-LowlyDbaSqlServerAuthSpec))
$sqlInstance, $sqlCredential = Get-SqlCredential -Module $module
$username = $module.Params.username
$database = $module.Params.database
$roles = $module.Params.roles

$module.Result.changed = $false

try {
    $getRoleSplat = @{
        SqlInstance = $sqlInstance
        SqlCredential = $sqlCredential
        EnableException = $true
    }
    if ($null -ne $roles) {
        $getRoleSplat.Add("Role", $roles)
    }
    if ($null -ne $database) {
        $getRoleSplat.Add("Database", $database)
    }
    if ($null -ne $username) {
        $output = Get-DbaDbRoleMember @getRoleSplat | Where-Object { $_.UserName -eq $username }
    }
    else {
        $output = Get-DbaDbRoleMember @getRoleSplat
    }

    if ($null -ne $output) {
        $resultData = ConvertTo-Json -InputObject $output -Depth 10
        $module.Result.data = $resultData
    }

    $module.ExitJson()

}
catch {
    $module.FailJson("Failure: $($_.Exception.Message)", $_)
}
