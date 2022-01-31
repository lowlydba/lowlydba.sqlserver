#!powershell

#AnsibleRequires -CSharpUtil Ansible.Basic
#AnsibleRequires -PowerShell ansible_collections.lowlydba.sqlserver.plugins.module_utils._MSSQLUtils

$ErrorActionPreference = "Stop"
Import-DbaTools

# Get Csharp utility module
$spec = @{
    supports_check_mode = $true
    options             = @{
        sql_instance = @{type = 'str'; required = $true }
        max_memory   = @{type = 'int'; required = $false; default = 0 }
        #TODO: Add Sql Auth support
    }
}
$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)
$SqlInstance = $module.Params.sql_instance
$MaxMemory = $module.Params.max_memory
$module.Result.changed = $false

# Set max memory for SQL Instance
try {
    $memResult = Test-DbaMaxMemory -SqlInstance $SqlInstance -EnableException
    if ($MaxMemory -eq 0) {
        $MaxMemory = $memResult.RecommendedValue
    }
    if ($memResult.MaxValue -ne $Maxmemory) {
        Set-DbaMaxMemory -SqlInstance $SqlInstance -Max $MaxMemory -WhatIf:$module.CheckMode -EnableException | Out-Null
        $module.Result.changed = $true
    }
    #TODO: Return output from Set- command
    $module.ExitJson()
}
catch {
    $module.FailJson("Error setting max memory.", $_.Exception.Message)
}
