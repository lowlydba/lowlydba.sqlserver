#!powershell
# -*- coding: utf-8 -*-

# (c) 2022, John McCall (@lowlydba)
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -CSharpUtil Ansible.Basic
#AnsibleRequires -PowerShell ansible_collections.lowlydba.sqlserver.plugins.module_utils._SqlServerUtils

Import-ModuleDependency
$ErrorActionPreference = "Stop"

# Get Csharp utility module
$spec = @{
    supports_check_mode = $true
    options = @{
        sql_instance = @{type = 'str'; required = $true }
        sql_username = @{type = "str"; required = $false }
        sql_password = @{type = "str"; required = $false; no_log = $true }
        database = @{type = 'str'; required = $true }
        nonquery = @{type = 'str'; required = $true }
        query_timeout = @{type = 'int'; required = $false; default = 60 }
    }
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)
$sqlInstance = $module.Params.sql_instance
$sqlUsername = $module.Params.sql_username
if ($null -ne $SqlUsername) {
    [securestring]$secPassword = ConvertTo-SecureString $module.Params.sql_password -AsPlainText -Force
    [pscredential]$sqlCredential = New-Object System.Management.Automation.PSCredential ($SqlUsername, $secPassword)
}
$database = $module.Params.database
$nonquery = $module.Params.nonquery
$queryTimeout = $module.Params.query_timeout
$checkMode = $module.CheckMode

$module.Result.changed = $false

try {
    if (-not($checkMode)) {
        $invokeQuerySplat = @{
            SqlInstance = $sqlInstance
            SqlCredential = $sqlCredential
            Database = $database
            Query = $nonquery
            QueryTimeout = $queryTimeout
            EnableException = $true
        }
        $null = Invoke-DbaQuery @invokeQuerySplat
    }
    $module.Result.changed = $true
    $module.ExitJson()
}
catch {
    $module.FailJson("Executing nonquery failed.", $_.Exception.Message)
}