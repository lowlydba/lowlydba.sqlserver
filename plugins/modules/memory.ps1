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
        sql_instance = @{type = "str"; required = $true }
        sql_username = @{type = "str"; required = $false }
        sql_password = @{type = "str"; required = $false; no_log = $true }
        max = @{type = "int"; required = $false; default = 0 }
    }
    required_together = @(, @("sql_username", "sql_password"))
}
$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)
$SqlUsername = $module.Params.sql_username
if ($null -ne $SqlUsername) {
    [securestring]$secPassword = ConvertTo-SecureString $module.Params.sql_password -AsPlainText -Force
    [pscredential]$sqlCredential = New-Object System.Management.Automation.PSCredential ($SqlUsername, $secPassword)
}
$sqlInstance = $module.Params.sql_instance
$max = $module.Params.max
$checkMode = $module.CheckMode
$module.Result.changed = $false

# Set max memory for SQL Instance
try {
    if ($checkMode) {
        # Make an equivalent output
        $output = Test-DbaMaxMemory -SqlInstance $sqlInstance -SqlCredential $sqlCredential -EnableException
        $output | Add-Member -MemberType NoteProperty -Name "PreviousMaxValue" -Value $output.MaxValue
        $output | Select-Object -ExcludeProperty "InstanceCount"
        $output.MaxValue = $max
    }
    else {
        # Set max memory
        $setMemorySplat = @{
            SqlInstance = $sqlInstance
            SqlCredential = $sqlCredential
            Max = $max
            EnableException = $true
        }
        $output = Set-DbaMaxMemory @setMemorySplat
    }

    if ($output.PreviousMaxValue -ne $max) {
        $module.Result.changed = $true
    }

    $outputHash = @{}
    foreach ($property in $output.PSObject.Properties ) {
        $propertyName = $property.Name
        if ($property.TypeNameOfValue -like "Microsoft*") {
            $outputHash[$propertyName] = $output.$propertyName.Name
        }
        else {
            $outputHash[$propertyName] = $output.$propertyName
        }
    }
    $module.Result.data = $outputHash
    $module.ExitJson()
}
catch {
    $module.FailJson("Error setting max memory.", $_.Exception.Message)
}
