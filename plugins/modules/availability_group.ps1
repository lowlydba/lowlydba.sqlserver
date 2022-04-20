#!powershell
# -*- coding: utf-8 -*-

# (c) 2022, John McCall (@lowlydba)
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -CSharpUtil Ansible.Basic
#AnsibleRequires -PowerShell ansible_collections.lowlydba.sqlserver.plugins.module_utils._SqlServerUtils
#Requires -Modules @{ ModuleName="dbatools"; ModuleVersion="1.1.87" }

$ErrorActionPreference = "Stop"

$spec = @{
    supports_check_mode = $true
    options = @{
        sql_instance_secondary = @{type = "str"; required = $false }
        #TODO secondary credential
        #TODO use_last_backup
        #TODO force
        database_name = @{type = "str"; required = $false }
        ag_name = @{type = "str"; required = $true }
        all_ags = @{type = "bool"; required = $false; }
        shared_path = @{type = "str"; required = $false; default = $null }
        dtc_support_enabled = @{type = "bool"; required = $false; }
        basic_availability_group = @{type = "bool"; required = $false; }
        database_health_trigger = @{type = "bool"; required = $false; }
        is_distributed_ag = @{type = "bool"; required = $false; }
        healthcheck_timeout = @{type = "int"; required = $false; }
        availability_mode = @{
            type = "str";
            required = $false;
            default = "SynchronousCommit"
            choices = @("SynchronousCommit", "AsynchronousCommit")
        }
        failure_condition_level = @{
            type = "str";
            required = $false;
            choices = @(
                "OnAnyQualifiedFailureCondition",
                "OnCriticalServerErrors",
                "OnModerateServerErrors",
                "OnServerDown",
                "OnServerUnresponsive"
            )
        }
        failover_mode = @{
            type = "str";
            required = $false;
            default = "Automatic";
            choices = @("Manual", "Automatic")
        }
        seeding_mode = @{
            type = "str";
            required = $false;
            default = "Manual";
            choices = @("Manual", "Automatic")
        }
        automated_backup_preference = @{
            type = "str";
            required = $false;
            default = "Secondary";
            choices = @("None", "Primary", "Secondary", "SecondaryOnly")
        }
        cluster_type = @{
            type = "str";
            required = $false;
            default = "Wsfc";
            choices = @("Wsfc", "External", "None")
        }
        allow_null_backup = @{type = "bool"; required = $false }
        state = @{type = "str"; required = $false; default = "present"; choices = @("present", "absent") }
    }
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec, @(Get-LowlyDbaSqlServerAuthSpec))
$sqlInstance, $sqlCredential = Get-SqlCredential -Module $module
$secondary = $module.Params.sql_instance_secondary
$agName = $module.Params.ag_name
[nullable[bool]]$all_ags = $module.Params.all_ags
$database = $module.Params.database_name
$seedingMode = $module.Params.seeding_mode
$sharedPath = $module.Params.shared_path
[nullable[bool]]$dtcSupportEnabled = $module.Params.dtc_support_enabled
[nullable[bool]]$basicAvailabilityGroup = $module.Params.basic_availability_group
[nullable[bool]]$databaseHealthTrigger = $module.Params.database_health_trigger
[nullable[bool]]$isDistributedAg = $module.Params.is_distributed_ag
$healthCheckTimeout = $module.Params.healthcheck_timeout
$availabilityMode = $module.Params.availability_mode
$failureConditionLevel = $module.Params.failure_condition_level
$failoverMode = $module.Params.failover_mode
$automatedBackupPreference = $module.Params.automated_backup_preference
$clusterType = $module.Params.cluster_type
$state = $module.Params.state
[nullable[bool]]$allowNullBackup = $module.Params.allow_null_backup
$checkMode = $module.CheckMode
$module.Result.changed = $false

try {
    $existingAG = Get-DbaAvailabilityGroup -SqlInstance $sqlInstance -SqlCredential $sqlCredential -AvailabilityGroup $agName -EnableException

    if ($state -eq "present") {
        $agSplat = @{
            Primary = $sqlInstance
            PrimarySqlCredential = $sqlCredential
            Name = $agName
            SeedingMode = $seedingMode
            FailoverMode = $failoverMode
            AvailabilityMode = $availabilityMode
            AutomatedBackupPreference = $automatedBackupPreference
            ClusterType = $clusterType
            WhatIf = $checkMode
            EnableException = $true
            Confirm = $false
        }
        if ($null -ne $sharedPath -and $seedingMode -eq "Manual") {
            $agSplat.Add("SharedPath", $sharedPath)
        }
        if ($dtcSupportEnabled -eq $true) {
            $agSplat.Add("DtcSupport", $dtcSupportEnabled)
        }
        if ($basicAvailabilityGroup -eq $true) {
            $agSplat.Add("Basic", $basicAvailabilityGroup)
        }
        if ($databaseHealthTrigger -eq $true) {
            $agSplat.Add("DatabaseHealthTrigger", $databaseHealthTrigger)
        }
        if ($null -ne $healthCheckTimeout) {
            $agSplat.Add("HealthCheckTimeout", $healthCheckTimeout)
        }
        if ($null -ne $failureConditionLevel) {
            $agSplat.Add("FailureConditionLevel", $failureConditionLevel)
        }
        if ($null -ne $database) {
            $agSplat.Add("Database", $database)
        }
        if ($null -ne $secondary) {
            $agSplat.Add("Secondary", $secondary)
        }

        # Create the AG with initial replica(s)
        if ($null -eq $existingAG) {
            # Full backup requirement for new AG via automatic seeding
            if ($seedingMode -eq "automatic" -and $null -ne $database) {
                $dbBackup = Get-DbaLastBackup -SqlInstance $sqlInstance -SqlCredential $sqlCredential -Database $database -EnableException
                if ($null -eq $dbBackup.LastFullBackup -and $allowNullBackup -eq $true) {
                    $backupSplat = @{
                        SqlInstance = $sqlInstance
                        SqlCredential = $sqlCredential
                        Database = $database
                        FilePath = "NUL"
                        Type = "Full"
                        EnableException = $true
                        Confirm = $false
                        WhatIf = $checkMode
                    }
                    $null = Backup-DbaDatabase $backupSplat
                }
            }
            $module.Result.output = $agSplat
            New-DbaAvailabilityGroup @agSplat -Verbose
            $module.Result.changed = $true
        }
        # Configure existing AG
        else {
            #TODO Compare all the properties here
            if ($existingAG.AutomatedBackupPreference -ne $automatedBackupPreference) {
                $setAgSplat = @{
                    AutomatedBackupPreference = $automatedBackupPreference
                    ClusterType = $clusterType
                    EnableException = $true
                    Confirm = $false
                    WhatIf = $checkMode
                }
                if ($all_ags -eq $true) {
                    $agSplat.Add("AllAvailabilityGroups", $all_ags)
                }
                if ($dtcSupportEnabled -eq $true) {
                    $setAgSplat.Add("DtcSupportEnabled", $dtcSupportEnabled)
                }
                if ($basicAvailabilityGroup -eq $true) {
                    $setAgSplat.Add("BasicAvailabilityGroup", $basicAvailabilityGroup)
                }
                if ($databaseHealthTrigger -eq $true) {
                    $setAgSplat.Add("DatabaseHealthTrigger", $databaseHealthTrigger)
                }
                if ($null -ne $failureConditionLevel) {
                    $setAgSplat.Add("FailureConditionLevel", $failureConditionLevel)
                }
                if ($null -ne $healthCheckTimeout) {
                    $setAgSplat.Add("HealthCheckTimeout", $healthCheckTimeout)
                }
                if ($isDistributedAg -eq $true) {
                    $agSplat.Add("IsDistributedAvailabilityGroup", $isDistributedAg)
                }
                $output = $existingAG | Set-DbaAvailabilityGroup @setAgSplat
                $module.Result.changed = $true
            }
        }
    }
    elseif ($state -eq $absent) {
        if ($null -ne $existingAG) {
            $removeAgSplat = @{
                Confirm = $false
                EnableException = $true
                WhatIf = $checkMode
            }
            if ($all_ags -eq $true) {
                $output = $existingAG | Remove-DbaAvailabilityGroup @removeAgSplat -AllAvailabilityGroups
            }
            else {
                $output = $existingAG | Remove-DbaAvailabilityGroup @removeAgSplat
            }
            $module.Result.changed = $true
        }
    }

    if ($output) {
        $resultData = ConvertTo-SerializableObject -InputObject $output
        $module.Result.data = $resultData
    }
    $module.ExitJson()
}
catch {
    $module.ExitJson()
    $module.FailJson("Configuring Availability Group failed: $($_.Exception.Message)", $_)
}
