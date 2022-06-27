#!powershell
# -*- coding: utf-8 -*-

# (c) 2022, John McCall (@lowlydba)
# (c) 2021, Sudhir Koduri (@kodurisudhir)
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -CSharpUtil Ansible.Basic
#AnsibleRequires -PowerShell ansible_collections.lowlydba.sqlserver.plugins.module_utils._SqlServerUtils
#Requires -Modules @{ ModuleName="dbatools"; ModuleVersion="1.1.108" }

$ErrorActionPreference = "Stop"

# Get Csharp utility module
$spec = @{
    supports_check_mode = $true
    options = @{
        port = @{type = 'int'; required = $true }
        ip_address = @{type = 'str'; required = $false }
    }
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec, @(Get-LowlyDbaSqlServerAuthSpec))
$sqlInstance, $sqlCredential = Get-SqlCredential -Module $module
$port = $module.Params.port
$ipAddress = $module.Params.ip_address
$checkMode = $module.CheckMode
$module.Result.changed = $false
$PSDefaultParameterValues = @{ "*:EnableException" = $true; "*:Confirm" = $false; "*:WhatIf" = $checkMode }

try {
    $existingPort = Get-DbaTcpPort -SqlInstance $sqlInstance -SqlCredential $sqlCredential

    if ($ipAddress -ne $existingPort.IPAddress -or $port -ne $existingPort.Port) {
        $tcpPortSplat = @{
            SqlInstance = $SqlInstance
            SqlCredential = $sqlCredential
            Port = $port
        }
        if ($ipAddress) {
            $tcpPortSplat.Add("IPAddress", $ipAddress)
        }
        $output = Set-DbaTcpPort @tcpPortSplat
        $module.Result.changed = $true
    }

    if ($null -ne $output) {
        $resultData = ConvertTo-SerializableObject -InputObject $output
        $module.Result.data = $resultData
    }
    $module.ExitJson()
}
catch {
    $module.FailJson("Configuring TCP port failed: $($_.Exception.Message)", $_)
}
