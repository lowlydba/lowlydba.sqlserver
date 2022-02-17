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
        database = @{type = 'str'; required = $true }
        data_file_path = @{type = 'str'; required = $false }
        owner_name = @{type = 'str'; required = $false; default = 'sa' }
        maxdop = @{type = 'int'; required = $false; default = 0 }
        secondary_maxdop = @{type = 'int'; required = $false; default = 4 }
        compatibility_mode = @{type = 'int'; required = $false; default = 15; choices = @(13, 14, 15) }
        rcsi = @{type = 'bool'; required = $false; default = $true }
        growth_type = @{type = 'str'; required = $false; default = 'MB'; choices = @('KB', 'MB', 'GB', 'TB') }
        growth = @{type = 'int'; required = $false; }
        state = @{type = 'str'; required = $false; default = 'present'; choices = @('present') }
    }
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)
$sqlInstance = $module.Params.sql_instance
$sqlUsername = $module.Params.sql_username
if ($null -ne $sqlUsername) {
    [securestring]$secPassword = ConvertTo-SecureString $module.Params.sql_password -AsPlainText -Force
    [pscredential]$sqlCredential = New-Object System.Management.Automation.PSCredential ($sqlUsername, $secPassword)
}
$database = $module.Params.database
$dataFilePath = $module.Params.data_file_path
$LogFilePath = $dataFilePath
$OwnerName = $module.Params.owner_name
$compatibilityMode = $module.Params.compatibility_mode
$rcsiEnabled = $module.Params.rcsi
$growthType = $module.Params.growth_type
$growth = $module.Params.growth
$maxDOP = $module.Params.maxdop
$secondaryMaxDOP = $module.Params.secondary_maxdop
$checkMode = $module.CheckMode
$module.Result.changed = $false

# Get database status
try {
    $getDatabaseHash = @{
        SqlInstance = $sqlInstance
        SqlCredential = $sqlCredential
        Database = $database
        OnlyAccessible = $true
        ExcludeSystem = $true
        EnableException = $true
    }
    $existingDatabase = Get-DbaDatabase @getDatabaseHash
}
catch {
    $module.FailJson("Error checking database status", $_.Exception.Message)
}

# Create database
if ($null -eq $existingDatabase) {
    try {
        $newDbParams = @{
            SqlInstance = $sqlInstance
            SqlCredential = $sqlCredential
            Database = $database
            Owner = $OwnerName
            EnableException = $true
        }
        if ($dataFilePath) {
            $newDbParams.Add("DataFilePath", $dataFilePath)
            $newDbParams.Add("LogFilePath", $LogFilePath)
        }
        $databaseOutput = New-DbaDatabase @newDbParams
        $module.Result.changed = $true
    }
    catch {
        $module.FailJson("Creating database failed", $_.Exception.Message)
    }
}

# Set Owner
elseif ($existingDatabase.Owner -ne $OwnerName) {
    try {
        $setDbParams = @{
            SqlInstance = $sqlInstance
            SqlCredential = $sqlCredential
            Database = $database
            TargetLogin = $OwnerName
            EnableException = $true
        }
        $ownerOutput = Set-DbaDbOwner @setDbParams
        $module.Result.changed = $true
    }
    catch {
        $module.FailJson("Setting database owner failed", $_.Exception.Message)
    }
}

# Compatibility Mode
try {
    $setCompatHash = @{
        SqlInstance = $sqlInstance
        SqlCredential = $sqlCredential
        Database = $database
        TargetCompatibility = $compatibilityMode
    }
    $compatOutput = Set-DbaDbCompatibility @setCompatHash
    $module.Result.changed = $true
}
catch {
    $module.FailJson("Setting Compatibility Mode for $database failed.", $_.Exception.Message)
}

# RCSI
try {
    $server = Connect-DbaInstance -SqlInstance $sqlInstance -SqlCredential $sqlCredential -EnableException
    if ($rcsiEnabled -ne $server.Databases[$database].IsReadCommittedSnapshotOn) {
        $server.Databases[$database].IsReadCommittedSnapshotOn = $rcsiEnabled
        $server.Databases[$database].Alter()
        $module.Result.changed = $true
    }
}
catch {
    $module.FailJson("Setting Read Commmitted Snapshot Isolation for $database failed.", $_.Exception.Message)
}

# Growth Rates
try {
    if ([int]$null -ne $Growth) {
        Set-DbaDbFileGrowth -SqlInstance $sqlInstance -SqlCredential $sqlCredential -Database $database -GrowthType $GrowthType -Growth $Growth | Out-Null
        $module.Result.changed = $true
    }
}
catch {
    $module.FailJson("Setting Database Growth for $database failed.", $_.Exception.Message)
}

# Configure MAXDOPs
## Database Scoped
try {
    $existingMaxDop = (Test-DbaMaxDop -SqlInstance $sqlInstance | Where-Object Database -eq $Database).DatabaseMaxDop
    if ($MaxDop -ne $existingMaxDop) {
        if (-not($checkMode)) {
            $setMaxDopHash = @{
                SqlInstance = $sqlInstance
                SqlCredential = $sqlCredential
                Database = $database
                MaxDop = $MaxDOP
                EnableException = $true
            }
            $null = Set-DbaMaxDop @setMaxDopHash
        }
        $output | Add-Member -MemberType NoteProperty -Name "MaxDop" -Value $MaxDOP
        $module.Result.changed = $true
    }
    else {
        $output | Add-Member -MemberType NoteProperty -Name "MaxDop" -Value $existingMaxDop
    }
}
catch {
    $module.FailJson("Setting MAXDOP failed.", $_.Exception.Message)
}
## Secondary Mode
try {

    $existingSecondaryMaxDop = $server.Databases[$database].MaxDopForSecondary
    if ($secondaryMaxDop -ne $existingSecondaryMaxDop) {
        if (-not($CheckMode)) {
            $server.Databases[$database].MaxDopForSecondary = $secondaryMaxDOP
            $server.Databases[$database].Alter()
        }
        $output | Add-Member -MemberType NoteProperty -Name "SecondaryMaxDop" -Value $secondaryMaxDop
        $module.Result.changed = $true
    }
    else {
        $output | Add-Member -MemberType NoteProperty -Name "SecondaryMaxDop" -Value $existingSecondaryMaxDop
    }
}
catch {
    $module.FailJson("Setting MAXDOP for secondary failed.", $_.Exception.Message)
}

$module.ExitJson()
