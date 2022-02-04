#!powershell
# -*- coding: utf-8 -*-

# (c) 2022, John McCall (@lowlydba)
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -CSharpUtil Ansible.Basic
#AnsibleRequires -PowerShell ansible_collections.lowlydba.sqlserver.plugins.module_utils._MSSQLUtils

$ErrorActionPreference = "Stop"
Import-DbaTools

# Get Csharp utility module
$spec = @{
    supports_check_mode = $true
    options = @{
        sql_instance = @{type = 'str'; required = $true }
        sql_username = @{type = 'str'; required = $false }
        sql_password = @{type = 'str'; required = $false; no_log = $true }
        max = @{type = 'int'; required = $false; default = 0 }
    }
    required_together = @(, @('sql_username', 'sql_password'))
}
$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)
$SqlUsername = $module.Params.sql_username
if ($null -ne $SqlUsername) {
    [securestring]$secPassword = ConvertTo-SecureString $module.Params.sql_password -AsPlainText -Force
    [pscredential]$sqlCredential = New-Object System.Management.Automation.PSCredential ($SqlUsername, $secPassword)
}
$SqlInstance = $module.Params.sql_instance
$MaxMemory = $module.Params.max
$module.Result.changed = $false

# Set max memory for SQL Instance
try {
    if ($MaxMemory -eq 0) {
        $MaxMemory = $memResult.RecommendedValue
    }
    $memResult = Test-DbaMaxMemory -SqlInstance $SqlInstance -SqlCredential $sqlCredential -EnableException
    if ($memResult.MaxValue -ne $Maxmemory) {
        $setMemorySplat = @{
            SqlInstance = $SqlInstance
            SqlCredential = $sqlCredential
            Max = $MaxMemory
            WhatIf = $module.CheckMode
            EnableException = $true
        }
        $outputHash = @{}
        $output = Set-DbaMaxMemory @setMemorySplat
        $module.Result.changed = $true
        foreach ($property in $output.PSObject.Properties ) {
            if ($property.TypeNameOfValue -like "Microsoft*") {
                $outputHash[$property.Name] = [System.String]$output.$($property.Name)
            }
            else {
                $outputHash[$property.Name] = $output.$($property.Name)
            }
        }
        $module.Result.data = $outputHash
    }
    $module.ExitJson()
}
catch {
    $module.FailJson("Error setting max memory.", $_.Exception.Message)
}
