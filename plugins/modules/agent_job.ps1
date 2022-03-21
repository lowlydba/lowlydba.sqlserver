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
        job = @{type = 'str'; required = $true }
        description = @{type = 'str'; required = $false; }
        category = @{type = 'str'; required = $false; }
        status = @{type = 'str'; required = $false; default = 'enabled'; choices = @('enabled', 'disabled') }
        owner_login = @{type = 'str'; required = $false; }
        start_step_id = @{type = 'int'; required = $false; }
        schedule = @{type = 'str'; required = $false; }
        force = @{type = 'bool'; required = $false; default = $false }
        state = @{type = 'str'; required = $false; default = 'present'; choices = @('present', 'absent') }
    }
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec, @(Get-LowlyDbaSqlServerAuthSpec))
$sqlInstance = $module.Params.sql_instance
$sqlCredential = Get-SqlCredential -Module $module
$job = $module.Params.job
$description = $module.Params.description
$status = $module.Params.status
[bool]$enabled = if ($status -eq "enabled") { $true } else { $false }
$ownerLogin = $module.Params.owner_login
$category = $module.Params.category
$schedule = $module.Params.schedule
[nullable[int]]$startStepId = $module.Params.start_step_id
$force = $module.Params.force
$state = $module.Params.state
$checkMode = $module.CheckMode
$module.Result.changed = $false

# Configure Agent job
try {
    $existingJob = Get-DbaAgentJob -SqlInstance $sqlInstance -SqlCredential $sqlCredential -Job $job -EnableException
    $output = $existingJob

    if ($state -eq "absent") {
        if ($null -ne $existingJob) {
            if (-not $checkMode) {
                $output = Remove-DbaAgentJob -SqlInstance $sqlInstance -SqlCredential $sqlCredential -Job $job -Confirm:$false -EnableException
            }
            $module.Result.changed = $true
        }
    }
    elseif ($state -eq "present") {
        $jobParams = @{
            SqlInstance = $sqlInstance
            SqlCredential = $sqlCredential
            Job = $job
            Force = $force
            EnableException = $true
        }

        if ($status -eq "disabled") {
            $jobParams.add("Disabled", $true)
        }

        if ($null -ne $ownerLogin) {
            $jobParams.add("OwnerLogin", $ownerLogin)
        }

        if ($null -ne $schedule) {
            $jobParams.add("Schedule", $schedule)
        }

        if ($null -ne $category) {
            $jobParams.add("Category", $category)
        }

        if ($null -ne $description) {
            $jobParams.add("Description", $description)
        }

        if ($null -ne $startStepID) {
            $jobParams.add("StartStepId", $startStepID)
        }

        # Create new job
        if ($null -eq $existingJob) {
            if (-not $checkMode) {
                try {
                    $output = New-DbaAgentJob @jobParams
                }
                catch {
                    $module.FailJson("Failed creating new agent job: $($_.Exception.Message)", $_)
                }
            }
            $module.Result.changed = $true
        }
        # Job exists
        else {
            # Compare existing values with passed params, skipping over values not specified
            $existingJob | Add-Member -MemberType NoteProperty -Name 'OwnerLogin' -Value $existingJob.OwnerLoginName
            $keys = $jobParams.Keys | Where-Object { $_ -ne 'SqlInstance' }
            $compareProperty = ($existingJob.Properties | Where-Object Name -in $keys).Name
            $diff = Compare-Object -ReferenceObject $existingJob -DifferenceObject $jobParams -Property $compareProperty
            # Update job
            if ($null -ne $diff -or $existingJob.IsEnabled -ne $enabled) {
                # Only one schedule / job supported currently - remove any others
                if ($existingJob.JobSchedules.Count -gt 1 -or $existingJob.JobSchedules.Name -contains $schedule) {
                    foreach ($sched in $existingJob.JobSchedules | Where-Object Name -ne $schedule ) {
                        if (-not $checkMode) {
                            $removeScheduleSplat = @{
                                SqlInstance = $sqlInstance
                                SqlCredential = $sqlCredential
                                Schedule = $schedule
                                EnableException = $true
                                Force = $true
                                Confirm = $false
                            }
                            $null = Remove-DbaAgentSchedule @removeScheduleSplat
                        }
                        $module.Result.changed = $true
                    }
                }

                # Update the job
                if (-not $checkMode) {
                    # Enabled is special flag only used in Set-DbaAgentJob
                    if ($status -eq "enabled") {
                        $jobParams.Add("Enabled", $true)
                    }
                    $output = Set-DbaAgentJob @jobParams
                }
                $module.Result.changed = $true
            }
        }
    }

    if ($output) {
        # $resultData = ConvertTo-SerializableObject -InputObject $output
        #  $module.Result.data = $resultData
    }
    $module.ExitJson()
}
catch {
    $module.FailJson("Error configuring SQL Agent job: $($_.Exception.Message)")
}
