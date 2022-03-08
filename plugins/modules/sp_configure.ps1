#!powershell
# -*- coding: utf-8 -*-

# (c) 2022, John McCall (@lowlydba)
# (c) 2021, Sudhir Koduri (@kodurisudhir)
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -CSharpUtil Ansible.Basic
#AnsibleRequires -PowerShell ansible_collections.lowlydba.sqlserver.plugins.module_utils._SqlServerUtils

$ErrorActionPreference = "Stop"
Import-ModuleDependency

# Get Csharp utility module
$spec = @{
    supports_check_mode = $true
    options = @{
        sql_instance = @{type = 'str'; required = $true }
        sql_username = @{type = "str"; required = $false }
        sql_password = @{type = "str"; required = $false; no_log = $true }
        name = @{type = 'str'; required = $true }
        value = @{type = 'int'; required = $true }
    }
    required_together = @(
        , @('sql_username', 'sql_password')
    )
}
$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)
$sqlInstance = $module.Params.sql_instance
$sqlUsername = $module.Params.sql_username
if ($null -ne $SqlUsername) {
    [securestring]$secPassword = ConvertTo-SecureString $module.Params.sql_password -AsPlainText -Force
    [pscredential]$sqlCredential = New-Object System.Management.Automation.PSCredential ($SqlUsername, $secPassword)
}
$name = $module.Params.name
$value = $module.Params.value
$checkMode = $module.CheckMode
$module.Result.changed = $false

# Make instance level system configuration change for a given configuration.
try {
    $output = Get-DbaSpConfigure -SqlInstance $sqlInstance -SqlCredential $sqlCredential -Name $name -EnableException
    $output | Add-Member -MemberType NoteProperty -Name "PreviousValue" -Value $output.ConfiguredValue
    $output = $output | Select-Object -Property ComputerName, InstanceName, SqlInstance, PreviousValue
    $output | Add-Member -MemberType NoteProperty -Name "ConfigName" -Value $name
    $output | Add-Member -MemberType NoteProperty -Name "NewValue" -Value $value

    if ($output.PreviousValue -ne $output.NewValue) {
        if ($checkMode -eq $false) {
            $setSpConfigureSplat = @{
                SqlInstance = $sqlInstance
                SqlCredential = $sqlCredential
                Name = $name
                Value = $value
                EnableException = $true
            }
            $output = Set-DbaSpConfigure @setSpConfigureSplat
        }
        $module.Result.changed = $true
    }

    $module.Result.data = Format-JsonOutput -Object $output
    $module.ExitJson()
}

catch {
    $module.FailJson("sp_configure change failed.", $_)
}
