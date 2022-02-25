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
        backup_location = @{type = 'str'; required = $false }
        cleanup_time = @{type = 'int'; required = $false; }
        output_file_dir = @{type = 'str'; required = $false }
        replace_existing = @{type = 'bool'; required = $false; }
        log_to_table = @{type = 'bool'; required = $false; default = $false }
        solution = @{type = 'str'; required = $false; choices = @('All', 'Backup', 'IntegrityCheck', 'IndexOptimize'); default = 'All' }
        install_jobs = @{type = 'bool'; required = $false; default = $false }
        local_file = @{type = 'str'; required = $false }
        database = @{type = 'str'; required = $true }
        force = @{type = 'bool'; required = $false; default = $false }
        install_parallel = @{type = 'bool'; required = $false; default = $false }
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
$database = $module.Params.database
$backupLocation = $module.Params.backup_location
$outputFileDirectory = $module.Params.output_file_dir
$cleanupTime = $module.Params.cleanup_time
$replaceExisting = $module.Params.replace_existing
$solution = $module.Params.solution
$installJobs = $module.Params.install_jobs
$installParallel = $module.Params.install_parallel
$logToTable = $module.Params.log_to_table
$localFile = $module.Params.local_file
$force = $module.Params.force
$module.Result.changed = $false

try {
    $maintenanceSolutionSplat = @{
        SqlInstance = $sqlInstance
        SqlCredential = $sqlCredential
        Database = $database
        LogToTable = $logToTable
        Solution = $solution
        InstallJobs = $installJobs
        InstallParallel = $installParallel
        Force = $force
        Confirm = $false
        EnableException = $true
    }
    if ($null -ne $localFile) {
        $maintenanceSolutionSplat.LocalFile = $localFile
    }
    if ($null -ne $backupLocation) {
        $maintenanceSolutionSplat.Branch = $backupLocation
    }
    if ($null -ne $outputFileDirectory) {
        $maintenanceSolutionSplat.OutputFileDirectory = $outputFileDirectory
    }
    if ($installJobs -eq $true -and $null -ne $cleanupTime) {
        $maintenanceSolutionSplat.CleanupTime = $cleanupTime
    }
    # Only pass if true, otherwise removes warning that is used to track changed=$false
    if ($replaceExisting -eq $true) {
        $maintenanceSolutionSplat.ReplaceExisting = $replaceExisting
    }

    try {
        $output = Install-DbaMaintenanceSolution @maintenanceSolutionSplat
        $module.Result.changed = $true
    }
    catch {
        $errMessage = $_.Exception.Message
        if ($errMessage -like "*Maintenance Solution already exists*") {
            $connection = Connect-DbaInstance -SqlInstance $sqlInstance -SqlCredential $sqlCredential
            $connection = $connection | Select-Object -Property ComputerName, InstanceName, SqlInstance
            $connection | Add-Member -MemberType NoteProperty -Name "Results" -Value "Success"
            $output = $connection
        }
        else {
            Write-Error -Message $errMessage
        }
    }

    $outputHash = ConvertTo-HashTable -Object $output
    $module.Result.data = $outputHash
    $module.ExitJson()
}
catch {
    $module.FailJson("Installing Maintenance Solution failed.", $_.Exception.Message)
}
