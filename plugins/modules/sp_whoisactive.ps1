#!powershell
# -*- coding: utf-8 -*-

# (c) 2022, John McCall (@lowlydba)
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -CSharpUtil Ansible.Basic
#AnsibleRequires -PowerShell ansible_collections.lowlydba.sqlserver.plugins.module_utils._SqlServerUtils

$ErrorActionPreference = "Stop"
Import-ModuleDependency

# Get Csharp utility module
$spec = @{
    supports_check_mode = $true
    options = @{
        database = @{type = 'str'; required = $true }
        local_file = @{type = 'str'; required = $false }
        force = @{type = 'bool'; required = $false; default = $false }
    }
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec, @(Get-LowlyDbaSqlServerAuthSpec))
$sqlInstance = $module.Params.sql_instance
$sqlCredential = Get-SqlCredential -Module $module
$database = $module.Params.database
$localFile = $module.Params.local_file
$force = $module.Params.force
$checkMode = $module.CheckMode
$module.Result.changed = $false

$name = "sp_whoisactive"
$status = "Installed"
$whoIsActiveSplat = @{
    SqlInstance = $SqlInstance
    SqlCredential = $SqlCredential
    Database = $Database
    Force = $force
    Confirm = $false
    EnableException = $true
}
if ($null -ne $LocalFile) {
    $whoIsActiveSplat.LocalFile = $LocalFile
}

try {
    if (-not $checkMode) {
        $output = Install-DbaWhoIsActive @whoIsActiveSplat
    }
    else {
        $getStoredProcSplat = @{
            SqlInstance = $sqlInstance
            SqlCredential = $sqlCredential
            Database = $database
            EnableException = $true
        }
        $server = Connect-DbaInstance -SqlInstance $sqlInstance -SqlCredential $sqlCredential
        $exists = Get-DbaDbStoredProcedure @getStoredProcSplat | Where-Object Name -eq $name
        if ($exists) {
            $status = "Updated"
        }
        $output = [PSCustomObject]@{
            ComputerName = $server.ComputerName
            InstanceName = $server.ServiceName
            SqlInstance = $server.DomainInstanceName
            Database = $database
            Name = $name
            Version = "n/a in check mode"
            Status = $status
        }
    }
    $module.Result.changed = $true

    $resultData = ConvertTo-SerializableObject -InputObject $output
    $module.Result.data = $resultData
    $module.ExitJson()
}
catch {
    $module.FailJson("Installing sp_WhoIsActive failed.", $_)
}
