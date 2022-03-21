#!powershell
# -*- coding: utf-8 -*-

# (c) 2022, John McCall (@lowlydba)
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -CSharpUtil Ansible.Basic
#AnsibleRequires -PowerShell ansible_collections.lowlydba.sqlserver.plugins.module_utils._SqlServerUtils

Import-ModuleDependency
$ErrorActionPreference = "Stop"

#TOD: Refactor these defaults / required values
$spec = @{
    supports_check_mode = $true
    options = @{
        job = @{type = 'str'; required = $true }
        step_id = @{type = 'int'; required = $false }
        step_name = @{type = 'str'; required = $true }
        database = @{type = 'str'; required = $false; default = 'master' }
        subsystem = @{type = 'str'; required = $false; default = 'TransactSql'; choices = @('CmdExec', 'Distribution', 'LogReader', 'Merge', 'PowerShell', 'QueueReader', 'Snapshot', 'Ssis', 'TransactSql') }
        command = @{type = 'str'; required = $false }
        on_success_action = @{type = 'str'; required = $false; default = 'QuitWithSuccess'; choices = @('QuitWithSuccess', 'QuitWithFailure', 'GoToNextStep', 'GoToStep') }
        on_success_step_id = @{type = 'int'; required = $false; default = 0 }
        on_fail_action = @{type = 'str'; required = $false; default = 'QuitWithFailure'; choices = @('QuitWithSuccess', 'QuitWithFailure', 'GoToNextStep', 'GoToStep') }
        on_fail_step_id = @{type = 'int'; required = $false; default = 0 }
        retry_attempts = @{type = 'int'; required = $false; default = 0 }
        retry_interval = @{type = 'int'; required = $false; default = 0 }
        state = @{type = 'str'; required = $false; default = 'present'; choices = @('present', 'absent') }
    }
    required_together = @(
        , @('retry_attempts', 'retry_interval')
    )
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec, @(Get-LowlyDbaSqlServerAuthSpec))
$sqlInstance = $module.Params.sql_instance
$sqlCredential = Get-SqlCredential -Module $module
$job = $module.Params.job
$stepId = $module.Params.step_id
$stepName = $module.Params.step_name
$database = $module.Params.database
$subsystem = $module.Params.subsystem
$command = $module.Params.command
$onSuccessAction = $module.Params.on_success_action
[nullable[int]]$onSuccessStepId = $module.Params.on_success_step_id
$onFailAction = $module.Params.on_fail_action
[nullable[int]]$onFailStepId = $module.Params.on_fail_step_id
[int]$retryAttempts = $module.Params.retry_attempts
[nullable[int]]$retryInterval = $module.Params.retry_interval
$state = $module.Params.state
$checkMode = $module.CheckMode
$module.Result.changed = $false

$jobStepParams = @{
    SqlInstance = $sqlInstance
    SqlCredential = $sqlCredential
    Job = $job
    StepName = $stepName
    Database = $database
    SubSystem = $subsystem
    OnSuccessAction = $onSuccessAction
    OnSuccessStepId = $onSuccessStepId
    OnFailAction = $onFailAction
    OnFailStepId = $onFailStepId
    RetryAttempts = $retryAttempts
    RetryInterval = $retryInterval
    EnableException = $true
}

if ($null -ne $command) {
    $jobStepParams.Add("Command", $command)
}

# Configure Agent job step
try {
    $existingJobSteps = Get-DbaAgentJobStep -SqlInstance $SqlInstance -SqlCredential $sqlCredential -Job $job
    $existingJobStep = $existingJobSteps | Where-Object Name -eq $stepName

    if ($state -eq "absent" -and $existingJobStep) {
        $removeStepSplat = @{
            SqlInstance = $sqlInstance
            SqlCredential = $sqlCredential
            Job = $job
            StepName = $stepName
            EnableException = $true
            Confirm = $false
        }
        if (-not $checkMode) {
            $output = Remove-DbaAgentJobStep @removeStepSplat
        }
        $module.Result.changed = $true
    }
    elseif ($state -eq "present") {
        # No existing job step
        if ($null -eq $existingJobStep) {
            $jobStepParams.Add("StepId", $stepId)
            if (-not $checkMode) {
                $output = New-DbaAgentJobStep @jobStepParams
            }
            $module.Result.changed = $true
        }
        # Update existing
        else {
            # Validate step name isn't taken already - must be unique within a job
            if ($existingJobStep.Name -eq $StepName -and $existingJobStep.ID -ne $stepId) {
                $module.FailJson("There is already a step named '$StepName' for this job with an ID of $($existingJobStep.ID).")
            }

            # Compare existing values with passed params, skipping over values not specified
            $keys = $jobStepParams.Keys | Where-Object { $_ -ne 'SqlInstance' }
            $compareProperty = ($existingJob.Properties | Where-Object Name -in $keys).Name
            $diff = Compare-Object -ReferenceObject $existingJobStep -DifferenceObject $jobStepParams -Property $compareProperty

            # Update the step
            if ($diff) {
                # Reference by old name in case new name differs for step id
                $jobStepParams.StepName = $existingJobStep.Name
                $jobStepParams.Add("NewName", $StepName)

                if (-not $checkMode) {
                    $output = Set-DbaAgentJobStep @jobStepParams
                }
                $module.Result.changed = $true
            }
        }
    }

    if ($null -ne $output) {
        $resultData = ConvertTo-SerializableObject -InputObject $output
        $module.Result.data = $resultData
    }
    $module.ExitJson()
}
catch {
    $module.FailJson("Error configuring SQL Agent job step.", $_)
}
