#!powershell
# -*- coding: utf-8 -*-

# (c) 2022, John McCall (@lowlydba)
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -CSharpUtil Ansible.Basic
#AnsibleRequires -PowerShell ansible_collections.lowlydba.sqlserver.plugins.module_utils._SqlServerUtils

Import-ModuleDependency
$ErrorActionPreference = "Stop"

$spec = @{
    supports_check_mode = $true
    options = @{
        sql_instance = @{type = 'str'; required = $true }
        sql_username = @{type = 'str'; required = $false }
        sql_password = @{type = 'str'; required = $false; no_log = $true }
        category = @{type = 'str'; required = $true }
        category_type = @{type = 'str'; required = $false; choices = @('LocalJob', 'MultiServerJob', 'None') }
        state = @{type = 'str'; required = $false; default = 'present'; choices = @('present', 'absent') }
    }
    required_together = @(
        , @('sql_username', 'sql_password')
    )
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)
$sqlInstance = $module.Params.sql_instance
$sqlUsername = $module.Params.sql_username
if ($null -ne $sqlUsername) {
    [securestring]$secPassword = ConvertTo-SecureString $module.Params.sql_password -AsPlainText -Force
    [pscredential]$sqlCredential = New-Object System.Management.Automation.PSCredential ($sqlUsername, $secPassword)
}
$category = $module.Params.category
$categoryType = $module.Params.category_type
$state = $module.Params.state
$checkMode = $module.CheckMode
$module.Result.changed = $false

try {
    $agentJobCategorySplat = @{
        SqlInstance = $sqlInstance
        SqlCredential = $sqlCredential
        Category = $category
        EnableException = $true
    }
    if ($null -ne $categoryType) {
        $agentJobCategorySplat.Add("CategoryType", $categoryType)
    }
    $output = Get-DbaAgentJobCategory @agentJobCategorySplat
    $server = Connect-DbaInstance -SqlInstance $sqlInstance -SqlCredential $sqlCredential

    if ($state -eq "present") {
        # Create new job category
        if ($null -eq $output) {
            if (-not $checkMode) {
                $output = New-DbaAgentJobCategory @agentJobCategorySplat
            }
            # Output for check mode
            else {
                $output = [PSCustomObject]@{
                    ComputerName = $server.ComputerName
                    InstanceName = $server.ServiceName
                    SqlInstance = $server.DomainInstanceName
                    Name = $category
                    ID = "n/a in check mode"
                    CategoryType = $categoryType
                    JobCount = 0
                }
            }
            $module.Result.changed = $true
        }
    }
    elseif ($state -eq "absent") {
        if ($output) {
            if (-not $checkMode) {
                $agentJobCategorySplat.Add("Confirm", $false)
                $output = Remove-DbaAgentJobCategory @agentJobCategorySplat
            }
            # Output for check mode
            else {
                $output = [PSCustomObject]@{
                    ComputerName = $server.ComputerName
                    InstanceName = $server.ServiceName
                    SqlInstance = $server.DomainInstanceName
                    Name = $category
                    Status = "Dropped"
                    IsRemoved = $true
                }
            }
            $module.Result.changed = $true
        }
    }
    $outputHash = ConvertTo-HashTable -Object $output
    $module.Result.data = $outputHash
    $module.ExitJson()
}
catch {
    $module.FailJson("Error modifying SQL Agent job category.", $_)
}
