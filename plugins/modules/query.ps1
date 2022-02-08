#!powershell

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
        query = @{type = 'str'; required = $true }
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
$query = $module.Params.query
$queryTimeout = $module.Params.query_timeout
$checkMode = $module.CheckMode

$module.Result.changed = $false

try {
    if (-not($checkMode)) {
        $invokeQuerySplat = @{
            SqlInstance = $sqlInstance
            SqlCredential = $sqlCredential
            Database = $database
            Query = $query
            QueryTimeout = $queryTimeout
            EnableException = $true
        }
        $null = Invoke-DbaQuery @invokeQuerySplat
    }
    $module.Result.changed = $true
    $module.ExitJson()
}
catch {
    $module.FailJson("Executing query failed.", $_.Exception.Message)
}
