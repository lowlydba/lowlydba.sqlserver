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
        recovery_model = @{type = 'str'; required = $false; choices = @('Full', 'Simple', 'BulkLogged') }
        data_file_path = @{type = 'str'; required = $false }
        log_file_path = @{type = 'str'; required = $false }
        owner_name = @{type = 'str'; required = $false; }
        maxdop = @{type = 'int'; required = $false; }
        secondary_maxdop = @{type = 'int'; required = $false; }
        compatibility = @{type = 'str'; required = $false; }
        rcsi = @{type = 'bool'; required = $false; }
        state = @{type = 'str'; required = $false; default = 'present'; choices = @('present', 'absent') }
    }
    required_together = @(
        ,@('sql_username', 'sql_password')
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
$recoveryModel = $module.Params.recovery_model
$dataFilePath = $module.Params.data_file_path
$logFilePath = $module.Params.log_file_path
$ownerName = $module.Params.owner_name
$compatibility = $module.Params.compatibility
[nullable[bool]]$rcsiEnabled = $module.Params.rcsi
[nullable[int]]$maxDop = $module.Params.maxdop
[nullable[int]]$secondaryMaxDop = $module.Params.secondary_maxdop
$state = $module.Params.state
$checkMode = $module.CheckMode

# Get database status
try {
    $server = Connect-DbaInstance -SqlInstance $sqlInstance -SqlCredential $sqlCredential
    $getDatabaseHash = @{
        SqlInstance = $sqlInstance
        SqlCredential = $sqlCredential
        Database = $database
        OnlyAccessible = $true
        ExcludeSystem = $true
        EnableException = $true
    }
    $output = Get-DbaDatabase @getDatabaseHash
}
catch {
    $module.FailJson("Error checking database status.", $_.Exception.Message)
}

if ($state -eq "absent") {
    if ($null -ne $output) {
        $dropHash = @{
            SqlInstance = $sqlInstance
            SqlCredential = $sqlCredential
            Database = $database
            EnableException = $true
            Confirm = $false
        }
        Remove-DbaDatabase @dropHash
        $module.Result.changed = $true
    }
    #TODO: Is it wrong to not return a useless dictionary of dropped db
    # attributes here? It makes different states = different output values.
    # or maybe default to a few basic properties (see memory module's output)
    $module.ExitJson()
}
elseif ($state -eq "present") {
    # Create database
    if ($null -eq $output) {
        try {
            $newDbParams = @{
                SqlInstance = $sqlInstance
                SqlCredential = $sqlCredential
                Database = $database
                Owner = $OwnerName
                EnableException = $true
            }
            if ($null -ne $dataFilePath) {
                $newDbParams.Add("DataFilePath", $dataFilePath)
            }
            if ($null -ne $logFilePath) {
                $newDbParams.Add("LogFilePath", $logFilePath)
            }
            $output = New-DbaDatabase @newDbParams
            $module.Result.changed = $true
        }
        catch {
            $module.FailJson("Creating database [$database] failed.", $_)
        }
    }

    # Set Owner
    elseif ($null -ne $ownerName) {
        try {
            if ($existingDatabase.Owner -ne $ownerName) {
                if (-not($checkMode)) {
                    $setDbParams = @{
                        SqlInstance = $sqlInstance
                        SqlCredential = $sqlCredential
                        Database = $database
                        TargetLogin = $ownerName
                        EnableException = $true
                    }
                    $null = Set-DbaDbOwner @setDbParams
                }
            }
            # Re-fetch the output since Owner is a read-only property
            $output = Get-DbaDatabase @getDatabaseHash
            $module.Result.changed = $true
        }
        catch {
            $module.FailJson("Setting database owner for [$database] failed.", $_)
        }
    }

    # Recovery Model
    if ($null -ne $recoveryModel) {
        try {
            if ($recoveryModel -ne $output.RecoveryModel) {
                if (-not($checkMode)) {
                    $recoveryModelHash = @{
                        SqlInstance = $sqlInstance
                        SqlCredential = $sqlCredential
                        Database = $database
                        RecoveryModel = $recoveryModel
                        EnableException = $true
                        Confirm = $false
                    }
                    $null = Set-DbaDbRecoveryModel @recoveryModelHash
                }
                $output.RecoveryModel = $recoveryModel
                $module.Result.changed = $true
            }
        }
        catch {
            $module.FailJson("Setting recovery model for [$database] failed.", $_.Exception.Message)
        }
    }

    # Compatibility Mode
    if ($null -ne $compatibility) {
        try {
            $existingCompatibility = $output.Compatibility
            if ($compatibility -ne $existingCompatibility) {
                if (-not($checkMode)) {
                    $compatHash = @{
                        SqlInstance = $sqlInstance
                        SqlCredential = $sqlCredential
                        Database = $database
                        Compatibility = $compatibility
                        EnableException = $true
                    }
                    $null = Set-DbaDbCompatibility @compatHash
                }
                $output.Compatibility = $compatibility
                $module.Result.changed = $true
            }
        }
        catch {
            $module.FailJson("Setting Compatibility for [$database] failed.", $_.Exception.Message)
        }
    }

    # RCSI
    $output | Add-Member -MemberType NoteProperty -Name "RCSI" -Value $server.Databases[$database].IsReadCommittedSnapshotOn
    $output.PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames.Add("RCSI")
    if ($null -ne $rcsiEnabled) {
        try {
            if ($rcsiEnabled -ne $output.RCSI) {
                if (-not($checkMode)) {
                    $server.Databases[$database].IsReadCommittedSnapshotOn = $rcsiEnabled
                    $server.Databases[$database].Alter()
                }
                $output.RCSI = $rcsiEnabled
                $module.Result.changed = $true
            }
        }
        catch {
            $module.FailJson("Setting Read Commmitted Snapshot Isolation for [$database] failed.", $_.Exception.Message)
        }
    }

    # Configure MAXDOPs
    ## Database Scoped MaxDop
    if ($null -ne $MaxDop) {
        try {
            $existingMaxDop = $server.Databases[$database].MaxDop
            $output.PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames.Add("MaxDop")
            $output.MaxDop = $existingMaxDop
            if ($MaxDop -ne $existingMaxDop) {
                if (-not($checkMode)) {
                    $server.Databases[$database].MaxDop = $maxDop
                    $server.Databases[$database].Alter()
                }
                $output.MaxDop = $MaxDOP
                $module.Result.changed = $true
            }
        }
        catch {
            $module.FailJson("Setting MAXDOP for [$database] failed.", $_.Exception.Message)
        }
    }

    ## Secondary Mode MaxDop
    [int]$existingSecondaryMaxDop = $server.Databases[$database].SecondaryMaxDop
    $output | Add-Member -MemberType NoteProperty -Name "SecondaryMaxDop" -Value $existingSecondaryMaxDop
    $output.PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames.Add("SecondaryMaxDop")
    if ($null -ne $secondaryMaxDOP) {
        try {
            if ($secondaryMaxDop -ne $output.SecondaryMaxDop) {
                if (-not($CheckMode)) {
                    $server.Databases[$database].MaxDopForSecondary = $secondaryMaxDOP
                    $server.Databases[$database].Alter()
                }
                $output.SecondaryMaxDop = $secondaryMaxDop
                $module.Result.changed = $true
            }
        }
        catch {
            $module.FailJson("Setting MaxDop for secondary mode for [$database] failed.", $_)
        }
    }
}
$outputHash = ConvertTo-HashTable -Object $output
$module.Result.data = $outputHash
$module.ExitJson()
