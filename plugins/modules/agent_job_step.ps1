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
    step_id = @{type = 'int'; required = $true }
    step_name = @{type = 'str'; required = $true }
    database = @{type = 'str'; required = $true }
    subsystem = @{type = 'str'; required = $false; choices = @('CmdExec', 'Distribution', 'LogReader', 'Merge', 'PowerShell', 'QueueReader', 'Snapshot', 'Ssis', 'TransactSql') }
    command = @{type = 'str'; required = $false }
    on_success_action = @{type = 'str'; required = $false; choices = @('QuitWithSuccess', 'QuitWithfailure', 'GoToNextStep', 'GoToStep') }
    on_success_step_id = @{type = 'int'; required = $false }
    on_fail_action = @{type = 'str'; required = $false; choices = @('QuitWithSuccess', 'QuitWithfailure', 'GoToNextStep', 'GoToStep') }
    on_fail_step_id = @{type = 'int'; required = $false }
    retry_attempts = @{type = 'int'; required = $false }
    retry_interval = @{type = 'int'; required = $false }
  }
  required_together = @(
    , @('retry_attempts', 'retry_interval')
  )
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec, @(Get-LowlyDbaSqlServerAuthSpec))
$sqlInstance = $module.Params.sql_instance
$sqlCredential = Get-SqlCredential -Module $module
$job = $module.Params.job
[int]$stepId = $module.Params.step_id
$stepName = $module.Params.step_name
$database = $module.Params.database
$subsystem = $module.Params.subsystem
$command = $module.Params.command
$onSuccessAction = $module.Params.on_success_action
[nullable[int]]$onSuccessStepId = $module.Params.on_success_step_id
$onFailAction = $module.Params.on_fail_action
[nullable[int]]$onFailStepId = $module.Params.on_fail_step_id
[nullable[int]]$retryAttempts = $module.Params.retry_attempts
[nullable[int]]$retryInterval = $module.Params.retry_interval
$module.Result.changed = $false

$existingJobStepParams = @{
  SqlInstance = $SqlInstance
  SqlCredential = $sqlCredential
  Job = $job
  StepName = $stepName
  StepId = $stepId
  Database = $database
  EnableException = $true
}

if ($null -ne $command) {
  $existingJobStepParams.Add("Command", $command)
}

if ($null -ne $subsystem) {
  $existingJobStepParams.Add("SubSystem", $subsystem)
}

if ($null -ne $onSuccessStepId) {
  $existingJobStepParams.Add("OnSuccessStepId", $onSuccessStepId)
}

if ($null -ne $onSuccessAction) {
  $existingJobStepParams.Add("OnSuccessAction", $onSuccessAction)
}

if ($null -ne $onFailStepId) {
  $existingJobStepParams.Add("OnFailStepId", $onFailStepId)
}

if ($null -ne $onFailAction) {
  $existingJobStepParams.Add("OnFailAction", $onFailAction)
}

if ($null -ne $retryAttempts) {
  $existingJobStepParams.Add("RetryAttempts", $RetryAttempts)
}

if ($null -ne $retryInterval) {
  $existingJobStepParams.Add("RetryInterval", $retryInterval)
}

# Configure Agent job step
try {
  $existingJobSteps = Get-DbaAgentJobStep -SqlInstance $SqlInstance -Job $JobName
  $existingJobStep = $existingJobSteps | Select-Object -First $StepId | Select-Object -Last 1

  # No existing job step
  if ($null -eq $existingJobStep) {
    $output = New-DbaAgentJobStep @jobStepParams
    $module.Result.changed = $true
  }
  # Update existing
  else {
    # Validate step name isn't taken already - must be unique within a job
    if ($existingJobSteps | Where-Object { $_.Name -eq $StepName -and $_.ID -ne $StepId }) {
      $module.FailJson("There is already a step named '$StepName' for this job.")
    }

    # Compare existing values with passed params, skipping over values not specified
    $keys = $existingJobStepParams.Keys | Where-Object { $_ -ne 'SqlInstance' }
    $compareProperty = ($existingJob.Properties | Where-Object Name -in $keys).Name
    $diff = Compare-Object -ReferenceObject $existingJobStep -DifferenceObject $jobStepParams -Property $compareProperty

    # Update the step
    if ($diff) {
      # Reference by old name in case new name differs for step id
      $existingJobStepParams.StepName = $existingJobStep.Name
      $existingJobStepParams.Add("NewName", $StepName)

      $output = Set-DbaAgentJobStep @jobStepParams
      $module.Result.changed = $true
    }
  }

  $resultData = ConvertTo-SerializableObject -InputObject $output
  $module.Result.data = $resultData
  $module.ExitJson()
}
catch {
  $module.FailJson("Error configuring SQL Agent job step.", $_)
}
