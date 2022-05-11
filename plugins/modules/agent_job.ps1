#!powershell
# -*- coding: utf-8 -*-

# (c) 2022, John McCall (@lowlydba)
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -CSharpUtil Ansible.Basic
#AnsibleRequires -PowerShell ansible_collections.lowlydba.sqlserver.plugins.module_utils._SqlServerUtils
#Requires -Modules @{ ModuleName="dbatools"; ModuleVersion="1.1.95" }

$ErrorActionPreference = "Stop"

$spec = @{
    supports_check_mode = $true
    options = @{
        job = @{type = 'str'; required = $true }
        description = @{type = 'str'; required = $false; }
        category = @{type = 'str'; required = $false; }
        enabled = @{type = 'bool'; required = $false; default = $true }
        owner_login = @{type = 'str'; required = $false; }
        start_step_id = @{type = 'int'; required = $false; }
        schedule = @{type = 'str'; required = $false; }
        force = @{type = 'bool'; required = $false; default = $false }
        state = @{type = 'str'; required = $false; default = 'present'; choices = @('present', 'absent') }
    }
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec, @(Get-LowlyDbaSqlServerAuthSpec))
$sqlInstance, $sqlCredential = Get-SqlCredential -Module $module
$job = $module.Params.job
$description = $module.Params.description
$enabled = $module.Params.enabled
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
            $output = $existingJob | Remove-DbaAgentJob -Confirm:$false -WhatIf:$checkMode -EnableException
            $module.Result.changed = $true
        }
    }
    elseif ($state -eq "present") {
        $jobParams = @{
            SqlInstance = $sqlInstance
            SqlCredential = $sqlCredential
            Job = $job
            WhatIf = $checkMode
            Force = $force
            EnableException = $true
        }

        if ($enabled -eq $false) {
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
            try {
                $null = New-DbaAgentJob @jobParams
                # Explicitly fetch the new job to make sure results don't suffer from SMO / Agent stale data bugs
                $output = Get-DbaAgentJob -SqlInstance $sqlInstance -SqlCredential $sqlCredential -Job $job -EnableException
            }
            catch {
                $module.FailJson("Failed creating new agent job: $($_.Exception.Message)", $_)
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
                # Update the job
                # Enabled is special flag only used in Set-DbaAgentJob
                if ($enabled -eq $true) {
                    $jobParams.Add("Enabled", $true)
                }
                $output = Set-DbaAgentJob @jobParams
                $module.Result.changed = $true
            }
        }
    }

    if ($output) {
        $resultData = ConvertTo-SerializableObject -InputObject $output
        $module.Result.data = $resultData
    }
    $module.ExitJson()
}
catch {
    $module.FailJson("Error configuring SQL Agent job: $($_.Exception.Message)", $_)
}
