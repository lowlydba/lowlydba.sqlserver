#!powershell
# -*- coding: utf-8 -*-

# (c) 2022, John McCall (@lowlydba)
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -CSharpUtil Ansible.Basic
#AnsibleRequires -PowerShell ansible_collections.lowlydba.sqlserver.plugins.module_utils._SqlServerUtils
#Requires -Modules @{ ModuleName="dbatools"; ModuleVersion="1.1.87" }

$ErrorActionPreference = "Stop"

# Get Csharp utility module
$spec = @{
    supports_check_mode = $true
    options = @{
        enabled = @{type = 'bool'; required = $false; default = $true }
        force = @{type = 'bool'; required = $false; default = $false }
    }
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec, @(Get-LowlyDbaSqlServerAuthSpec))
$sqlInstance, $sqlCredential = Get-SqlCredential -Module $module
$enabled = $module.Params.enabled
$force = $module.Params.force
$checkMode = $module.CheckMode
$module.Result.changed = $false

try {
    $existingHadr = Get-DbaAgHadr -SqlInstance $sqlInstance -SqlCredential $sqlCredential -EnableException
    if ($existingHadr.IsHadrEnabled -ne $enabled) {
        $setHadr = @{
            SqlInstance = $sqlInstance
            SqlCredential = $sqlCredential
            WhatIf = $checkMode
            Force = $force
            Confirm = $false
            EnableException = $true
        }
        if ($enabled -eq $false) {
            $output = Disable-DbaAgHadr @setHadr
        }
        else {
            $output = Enable-DbaAgHadr @setHadr
        }
        $module.Result.changed = $true
    }

    if ($null -ne $output) {
        $resultData = ConvertTo-SerializableObject -InputObject $output
        $module.Result.data = $resultData
    }
    $module.ExitJson()
}
catch {
    $module.FailJson("Error configuring Hadr.", $_)
}