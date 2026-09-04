#!powershell
# -*- coding: utf-8 -*-

# (c) 2022, John McCall (@lowlydba)
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -CSharpUtil Ansible.Basic
#AnsibleRequires -PowerShell ansible_collections.lowlydba.sqlserver.plugins.module_utils._SqlServerUtils
#Requires -Modules @{ ModuleName="dbatools"; ModuleVersion="2.0.0" }

$ErrorActionPreference = "Stop"

$spec = @{
    supports_check_mode = $true
    options = @{
        job = @{type = 'str'; required = $true }
        step_id = @{type = 'int'; required = $false }
        step_name = @{type = 'str'; required = $false }
        database = @{type = 'str'; required = $false; default = 'master' }
        subsystem = @{type = 'str'; required = $false; default = 'TransactSql'
            choices = @('CmdExec', 'Distribution', 'LogReader', 'Merge', 'PowerShell', 'QueueReader', 'Snapshot', 'Ssis', 'TransactSql')
        }
        command = @{type = 'str'; required = $false }
        on_success_action = @{type = 'str'; required = $false; default = 'QuitWithSuccess'
            choices = @('QuitWithSuccess', 'QuitWithFailure', 'GoToNextStep', 'GoToStep')
        }
        on_success_step_id = @{type = 'int'; required = $false; default = 0 }
        on_fail_action = @{type = 'str'; required = $false; default = 'QuitWithFailure'
            choices = @('QuitWithSuccess', 'QuitWithFailure', 'GoToNextStep', 'GoToStep')
        }
        on_fail_step_id = @{type = 'int'; required = $false; default = 0 }
        retry_attempts = @{type = 'int'; required = $false; default = 0 }
        retry_interval = @{type = 'int'; required = $false; default = 0 }
        output_file = @{type = 'str'; required = $false }
        state = @{type = 'str'; required = $false; default = 'present'; choices = @('present', 'absent') }
    }
    required_together = @(
        , @('retry_attempts', 'retry_interval')
    )
    required_one_of = @(
        , @('step_id', 'step_name')
    )
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec, @(Get-LowlyDbaSqlServerAuthSpec))
$sqlInstance, $sqlCredential = Get-SqlCredential -Module $module
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
$outputFile = $module.Params.output_file
$state = $module.Params.state
$checkMode = $module.CheckMode
$module.Result.changed = $false
$PSDefaultParameterValues = @{ "*:EnableException" = $true; "*:Confirm" = $false; "*:WhatIf" = $checkMode }

# Configure Agent job step
try {
    $existingJobSteps = Get-DbaAgentJobStep -SqlInstance $SqlInstance -SqlCredential $sqlCredential -Job $job

    if ($state -eq "absent") {
        # Either step_id or step_name may be supplied; look up by whichever is available.
        $existingJobStep = $null
        if ($stepId) {
            $existingJobStep = $existingJobSteps | Where-Object Id -eq $stepId
        }
        if ($null -eq $existingJobStep -and $stepName) {
            $existingJobStep = $existingJobSteps | Where-Object Name -eq $stepName
        }
        if ($existingJobStep) {
            $removeStepSplat = @{
                SqlInstance = $sqlInstance
                SqlCredential = $sqlCredential
                Job = $job
                StepName = $existingJobStep.Name
            }
            $output = Remove-DbaAgentJobStep @removeStepSplat
            $module.Result.changed = $true
        }
    }
    elseif ($state -eq "present") {
        if (!($stepName) -or !($stepId)) {
            $module.FailJson("Step name and step_id must be specified when state=present.")
        }
        # step_id and step_name are both required here, and step_name may be a new name for an
        # existing step (rename), so look up strictly by the immutable id rather than by name.
        $existingJobStep = $existingJobSteps | Where-Object Id -eq $stepId

        # Validate step name isn't taken already by another step - must be unique within a job.
        # This covers both renaming onto an already-taken name and creating a new step whose
        # name collides with an existing one under a different step_id.
        $conflictingStep = $existingJobSteps | Where-Object { $_.Name -eq $stepName -and $_.ID -ne $stepId }
        if ($conflictingStep) {
            $module.FailJson("There is already a step named '$stepName' for this job with an ID of $($conflictingStep.ID).")
        }

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
        }
        if ($null -ne $command) {
            $jobStepParams.Add("Command", $command)
        }

        # No existing job step
        if ($null -eq $existingJobStep) {
            $jobStepParams.Add("StepId", $stepId)
            $output = New-DbaAgentJobStep @jobStepParams
            $module.Result.changed = $true

            # Set output file if specified
            if ($null -ne $outputFile -and $outputFile -ne "") {
                $setOutputFileSplat = @{
                    SqlInstance = $sqlInstance
                    SqlCredential = $sqlCredential
                    Job = $job
                    Step = $stepName
                    OutputFile = $outputFile
                }
                $null = Set-DbaAgentJobOutputFile @setOutputFileSplat
            }
        }
        # Update existing
        else {
            # Reference by old name in case new name differs for step id
            $jobStepParams.StepName = $existingJobStep.Name
            $jobStepParams.Add("NewName", $StepName)

            # Need to serialize to prevent SMO auto refreshing
            $old = ConvertTo-SerializableObject -InputObject $existingJobStep -UseDefaultProperty $false
            $output = Set-DbaAgentJobStep @jobStepParams
            if ($null -ne $output) {
                $compareProperty = @(
                    "Name"
                    "DatabaseName"
                    "Command"
                    "Subsystem"
                    "OnFailAction"
                    "OnFailActionStep"
                    "OnSuccessAction"
                    "OnSuccessActionStep"
                    "RetryAttempts"
                    "RetryInterval"
                    "OutputFileName"
                )
                $diff = Compare-Object -ReferenceObject $output -DifferenceObject $old -Property $compareProperty
            }

            # Set output file if specified and different from current
            if ($null -ne $outputFile -and $outputFile -ne "" -and $existingJobStep.OutputFileName -ne $outputFile) {
                $setOutputFileSplat = @{
                    SqlInstance = $sqlInstance
                    SqlCredential = $sqlCredential
                    Job = $job
                    Step = $stepName  # Use the new step name since Set-DbaAgentJobStep already renamed it
                    OutputFile = $outputFile
                }
                $null = Set-DbaAgentJobOutputFile @setOutputFileSplat
                $module.Result.changed = $true
            }

            if ($diff -or $checkMode) {
                $module.Result.changed = $true
            }
        }

        # Re-read the step so data reflects server state; SMO can lag briefly after a rename, so retry a few times
        if (-not $checkMode -and $null -ne $output) {
            for ($attempt = 0; $attempt -lt 5; $attempt++) {
                $refreshed = Get-DbaAgentJobStep -SqlInstance $SqlInstance -SqlCredential $sqlCredential -Job $job | Where-Object Name -eq $stepName
                if ($null -ne $refreshed) {
                    break
                }
                Start-Sleep -Milliseconds 500
            }
            if ($null -ne $refreshed) {
                $output = $refreshed
            }
        }
    }

    if ($null -ne $output) {
        # Get-DbaAgentJobStep trims the default view (no ID, DatabaseName, OutputFileName), so serialize the full object
        $resultData = ConvertTo-SerializableObject -InputObject $output -UseDefaultProperty $false
        $module.Result.data = $resultData
    }
    $module.ExitJson()
}
catch {
    $module.FailJson("Error configuring SQL Agent job step.", $_)
}
