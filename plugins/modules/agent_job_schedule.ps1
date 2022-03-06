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
        schedule = @{type = 'str'; required = $true }
        job = @{type = 'str'; required = $false }
        status = @{type = 'str'; required = $false; default = 'Enabled'; choices = @('Enabled', 'Disabled') }
        force = @{type = 'bool'; required = $false }
        frequency_type = @{type = 'str'; required = $false; choices = @('Once', 'OneTime', 'Daily', 'Weekly', 'Monthly', 'MonthlyRelative', 'AgentStart', 'AutoStart', 'IdleComputer', 'OnIdle') }
        frequency_interval = @{type = 'str'; required = $false; }
        frequency_subday_type = @{type = 'str'; required = $false; choices = @('Time', 'Seconds', 'Minutes', 'Hours') }
        frequency_subday_interval = @{type = 'int'; required = $false }
        frequency_relative_interval = @{type = 'str'; required = $false; choices = @('Unused', 'First', 'Second', 'Third', 'Fourth', 'Last') }
        frequency_recurrence_factor = @{type = 'int'; required = $false }
        start_date = @{type = 'str'; required = $false }
        end_date = @{type = 'str'; required = $false }
        start_time = @{type = 'str'; required = $false }
        end_time = @{type = 'str'; required = $false }
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
$schedule = $module.Params.schedule
$job = $module.Params.job
$status = $module.Params.status
$force = $module.Params.force
$frequencyType = $module.Params.frequency_type
$frequencyInterval = $module.Params.frequency_interval
$frequencySubdayType = $module.Params.frequency_subday_type
[nullable[int]]$frequencySubdayInterval = $module.Params.frequency_subday_interval
$frequencyRelativeInterval = $module.Params.frequency_relative_interval
[nullable[int]]$frequencyRecurrenceFactor = $module.Params.frequency_recurrence_factor
$startDate = $module.Params.start_date
$endDate = $module.Params.end_date
$startTime = $module.Params.start_time
$endTime = $module.Params.end_time
$state = $module.Params.state
$module.Result.changed = $false

$scheduleParams = @{
    SqlInstance = $SqlInstance
    SqlCredential = $sqlCredential
    Job = $job
    Force = $force
    Schedule = $schedule
    FrequencyType = $frequencyType
    EnableException = $true
}

if ($status -eq "disabled") {
    $scheduleParams.add("Disabled", $true)
}
if ($null -ne $startDate) {
    $scheduleParams.add("StartDate", $startDate)
}
if ($null -ne $endDate) {
    $scheduleParams.add("EndDate", $endDate)
}
if ($null -ne $startTime) {
    $scheduleParams.add("StartTime", $startTime)
}
if ($null -ne $endTime) {
    $scheduleParams.add("EndTime", $endTime)
}
if ($null -ne $frequencyInterval) {
    $scheduleParams.add("FrequencyInterval", $frequencyInterval)
}
if ($null -ne $frequencySubdayType) {
    $scheduleParams.add("FrequencySubdayType", $frequencySubdayType)
}
if ($null -ne $frequencySubdayInterval) {
    $scheduleParams.add("FrequencySubdayInterval", $frequencySubdayInterval)
}
if ($null -ne $frequencyRelativeInterval) {
    $scheduleParams.add("FrequencyRelativeInterval", $frequencyRelativeInterval)
}
if ($null -ne $frequencyRecurrenceFactor) {
    $scheduleParams.add("FrequencyRecurrenceFactor", $frequencyRecurrenceFactor)
}

try {
    $existingSchedule = Get-DbaAgentSchedule -SqlInstance $SqlInstance -Schedule $ScheduleName -EnableException

    if ($state -eq "present") {
        # Update schedule
        if ($null -ne $existingSchedule) {
            if (-not $checkMode) {
                $output = Set-DbaAgentSchedule @scheduleParams
                # Check if schedule was actually changed
                $newSchedule = Get-DbaAgentSchedule -SqlInstance $SqlInstance -Schedule $ScheduleName -EnableException
                $scheduleDiff = Compare-Object -ReferenceObject $existingSchedule -DifferenceObject $newSchedule
                if ($null -ne $scheduleDiff) {
                    $module.Result.changed = $true
                }
            }
            # Assume updated for checkmode
            else {
                $module.Result.changed = $true
            }
        }
        # Create schedule
        else {
            if (-not $checkMode) {
                $output = New-DbaAgentSchedule @scheduleParams
            }
            $module.Result.changed = $true
        }
    }
    elseif ($state -eq "absent" -and $null -ne $existingSchedule) {
        if (-not $checkMode) {
            $removeScheduleSplat = @{
                SqlInstance = $sqlInstance
                SqlCredential = $sqlCredential
                Schedule = $schedule
                Force = $true
            }
            $output = Remove-DbaAgentSchedule @removeScheduleSplat
        }
        $module.Result.changed = $true
    }
    $outputHash = ConvertTo-HashTable -Object $output
    $module.Result.data = $outputHash
    $module.ExitJson()
}
catch {
    $module.FailJson("Error configuring SQL Agent job schedule.", $_)
}
