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
  options             = @{
    job_name           = @{type = 'str'; required = $true }
    step_id            = @{type = 'int'; required = $true }
    step_name          = @{type = 'str'; required = $true }
    database_name      = @{type = 'str'; required = $true }
    subsystem          = @{type = 'str'; required = $true; choices = @('ActiveScripting', 'AnalysisCommand', 'AnalysisQuery', 'CmdExec', 'Distribution', 'LogReader', 'Merge', 'PowerShell', 'QueueReader', 'Snapshot', 'Ssis', 'TransactSql') }
    command            = @{type = 'str'; required = $true }
    on_success_action  = @{type = 'str'; required = $true; choices = @('QuitWithSuccess', 'QuitWithfailure', 'GoToNextStep', 'GoToStep') }
    on_success_step_id = @{type = 'int'; required = $false; default = 0 }
    on_fail_action     = @{type = 'str'; required = $true ; choices = @('QuitWithSuccess', 'QuitWithfailure', 'GoToNextStep', 'GoToStep') }
    on_fail_step_id    = @{type = 'int'; required = $false; default = 0 }
    retry_attempts     = @{type = 'int'; required = $false; default = 0 }
    retry_interval     = @{type = 'int'; required = $false; default = 0 }
  }
  required_together   = @(
    , @('retry_attempts', 'retry_interval')
  )
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec, @(Get-LowlyDbaSqlServerAuthSpec))
$sqlInstance = $module.Params.sql_instance
$JobName = $module.Params.job_name
[int]$StepId = $module.Params.step_id
$StepName = $module.Params.step_name
$DatabaseName = $module.Params.database_name
$Subsystem = $module.Params.subsystem
$Command = $module.Params.command
$OnSuccessAction = $module.Params.on_success_action
[int]$OnSuccessStepId = $module.Params.on_success_step_id
$OnFailAction = $module.Params.on_fail_action
[int]$OnFailStepId = $module.Params.on_fail_step_id
[int]$RetryAttempts = $module.Params.retry_attempts
[int]$RetryInterval = $module.Params.retry_interval
$module.Result.changed = $false

$jobStepParams = @{
  SqlInstance     = $SqlInstance
  Job             = $JobName
  Database        = $DatabaseName
  Subsystem       = $Subsystem
  Command         = $Command
  OnSuccessAction = $OnSuccessAction
  OnSuccessStepId = $OnSuccessStepId
  OnFailAction    = $OnFailAction
  OnFailStepId    = $OnFailStepId
  RetryAttempts   = $RetryAttempts
  RetryInterval   = $RetryInterval
  EnableException = $true
}

# Configure Agent job step
try
{
  $existingJobSteps = Get-DbaAgentJobStep -SqlInstance $SqlInstance -Job $JobName
  # No existing job step
  if ($null -eq $existingJobSteps) {
    $jobStepParams.Add("StepName", $StepName)
    $output = New-DbaAgentJobStep @jobStepParams
    $module.Result.changed = $true
  }
  # Update existing
  else
  {
    $stepArrayIndex = $StepId - 1 # Powershell uses 0 based array indexing, Agent uses 1 based
    $jobStep = $existingJobSteps[$stepArrayIndex]

    # No changes
    # TODO: Use Compare-Object here instead
    if ($jobStep.Name -eq $StepName -and `
      $jobStep.DatabaseName -eq $DatabaseName -and `
      $jobStep.Command -eq $Command -and `
      $jobStep.Subsystem -eq $Subsystem -and `
      $jobStep.OnSuccessAction -eq $OnSuccessAction -and `
      ($jobStep.OnSuccessStepId -in ($null, 0) -or $jobStep.OnSuccessStepId -eq $OnSuccessStepId) -and `
      $jobStep.OnFailAction -eq $OnFailAction -and `
      ($jobStep.OnFailStepId -in ($null, 0) -or $jobStep.OnFailStepId -eq $OnFailStepId) -and `
      $jobStep.RetryAttempts -eq $RetryAttempts -and `
      $jobStep.RetryInterval -eq $RetryInterval)
    {
      
    }
    # Update the step
    elseif ($null -ne $jobStep)
    {
      # If the new step name already exists as a different step than the one being modified,
      # it needs to be removed since step names must be unique within a job.
      if ($StepName -ne $jobStep.Name) {
        if ($existingJobSteps | Where-Object {$_.Name -eq $StepName -and $_.ID -ne $StepId}) {
          Remove-DbaAgentJobStep -SqlInstance $SqlInstance -Job $JobName -StepName $StepName -EnableException -WhatIf:$($module.CheckMode) | Out-Null
        }
      }

      # Reference by old name in case new name differs
      $jobStepParams.Add("StepName", $jobStep.Name)
      $jobStepParams.Add("NewName", $StepName)

      $output = Set-DbaAgentJobStep @jobStepParams
      $module.Result.changed = $true
    }
  }

  $module.ExitJson()
}
catch
{
  $module.FailJson("Error modifying SQL Agent job step.", $_)
}
