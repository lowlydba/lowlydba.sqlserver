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
        trace_flag = @{type = 'int'; required = $true }
        enabled = @{type = 'bool'; required = $true }
    }
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec, @(Get-LowlyDbaSqlServerAuthSpec))
$sqlInstance = $module.Params.sql_instance
$sqlCredential = Get-SqlCredential -Module $module
$traceFlag = $module.Params.trace_flag
$enabled = $module.Params.enabled
$checkMode = $module.CheckMode
$module.Result.changed = $false

try {
    $traceFlagSplat = @{
        SqlInstance = $SqlInstance
        SqlCredential = $sqlCredential
        TraceFlag = $traceFlag
        EnableException = $true
    }
    $existingFlag = Get-DbaTraceFlag @traceFlagSplat
    $server = Connect-DbaInstance -SqlInstance $sqlInstance -SqlCredential $sqlCredential

    if ($checkMode) {
        $output = [PSCustomObject]@{
            InstanceName = $server.ServiceName
            SqlInstance = $server.DomainInstanceName
            TraceFlag = $traceFlag
        }
    }

    if ($enabled -eq $true) {
        if ($existingFlag.TraceFlag -notcontains $traceFlag) {
            $module.Result.changed = $true
        }
        if (-not $checkMode) {
            $enabled = Enable-DbaTraceFlag @traceFlagSplat
            $output = $enabled | Select-Object -Property InstanceName, SqlInstance, TraceFlag
        }
        else {
            $output = $server | Select-Object -Property InstanceName, SqlInstance
            $output | Add-Member -MemberType NoteProperty -Name "TraceFlag" -Value $traceFlag
        }
    }
    elseif ($enabled -eq $false) {
        if ($existingFlag.TraceFlag -contains $traceFlag) {
            $module.Result.changed = $true
        }
        if (-not $checkMode) {
            $disabled = Disable-DbaTraceFlag @traceFlagSplat
            $output = $disabled | Select-Object -Property InstanceName, SqlInstance, TraceFlag
        }
        else {
        }
    }

    $resultData = ConvertTo-SerializableObject -InputObject $output
    $module.Result.data = $resultData
    $module.ExitJson()
}
catch {
    $module.FailJson("Changing trace flag failed.", $_)
}
