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
        description = @{type = 'str'; required = $false; }
        category = @{type = 'str'; required = $false; }
        enabled = @{type = 'bool'; required = $false; default = $true }
        owner_login = @{type = 'str'; required = $false; }
        start_step_id = @{type = 'int'; required = $false; }
        schedule = @{type = 'str'; required = $false; }
        force = @{type = 'bool'; required = $false; default = $false }
        state = @{type = 'str'; required = $false; default = 'present'; choices = @('present', 'absent') }
        output_file = @{type = 'str'; required = $false; }
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
$outputFile = $module.Params.output_file
$checkMode = $module.CheckMode
$module.Result.changed = $false
$PSDefaultParameterValues = @{ "*:EnableException" = $true; "*:Confirm" = $false; "*:WhatIf" = $checkMode }

# Configure Agent job
try {
    $existingJob = Get-DbaAgentJob -SqlInstance $sqlInstance -SqlCredential $sqlCredential -Job $job -EnableException
    $output = $existingJob

    if ($state -eq "absent") {
        if ($null -ne $existingJob) {
            $output = $existingJob | Remove-DbaAgentJob
            $module.Result.changed = $true
        }
    }
    elseif ($state -eq "present") {
        $jobParams = @{
            SqlInstance = $sqlInstance
            SqlCredential = $sqlCredential
            Job = $job
            Force = $force
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
                $output = Get-DbaAgentJob -SqlInstance $sqlInstance -SqlCredential $sqlCredential -Job $job
            }
            catch {
                $module.FailJson("Failed creating new agent job: $($_.Exception.Message)", $_)
            }
            $module.Result.changed = $true
        }
        # Job exists
        else {
            # Need to serialize to prevent SMO auto refreshing
            $old = ConvertTo-SerializableObject -InputObject $existingJob -UseDefaultProperty $false
            if ($enabled -eq $true) {
                $jobParams.Add("Enabled", $true)
            }
            $output = Set-DbaAgentJob @jobParams
            if ($null -ne $output) {
                $compareProperty = @(
                    "Category"
                    "Enabled"
                    "Name"
                    "OwnerLoginName"
                    "HasSchedule"
                    "Description"
                    "StartStepId"
                )
                $diff = Compare-Object -ReferenceObject $output -DifferenceObject $old -Property $compareProperty
                if ($diff -or $checkMode) {
                    $module.Result.changed = $true
                }
            }
        }

        # Set output file if specified
        if ($null -ne $outputFile) {
            try {
                # Read current configured output file
                $beforeObj = Get-DbaAgentJobOutputFile -SqlInstance $sqlInstance -SqlCredential $sqlCredential -Job $job
                $beforeValue = $beforeObj.OutputFile

                if (-not $checkMode) {
                    # Set the requested output file
                    $null = Set-DbaAgentJobOutputFile -SqlInstance $sqlInstance -SqlCredential $sqlCredential -Job $job -OutputFile $outputFile

                    # Refresh the job object to ensure SMO reflects the change
                    $jobObj = Get-DbaAgentJob -SqlInstance $sqlInstance -SqlCredential $sqlCredential -Job $job -EnableException
                    if ($jobObj -is [System.Collections.IEnumerable] -and -not ($jobObj -is [string])) { $jobObj = $jobObj | Select-Object -First 1 }
                    try { $jobObj.Refresh() } catch { }

                    # Re-read the output-file value reported by dbatools
                    $afterObj = Get-DbaAgentJobOutputFile -SqlInstance $sqlInstance -SqlCredential $sqlCredential -Job $job
                    $afterValue = $afterObj.OutputFile

                    $outputFileResult = @{ OutputFile = $afterValue }
                    $module.Result.changed = $beforeValue -ne $afterValue
                }
                else {
                    # Check mode: predict change without making it
                    $outputFileResult = @{ OutputFile = $outputFile }
                    $module.Result.changed = $beforeValue -ne $outputFile
                }
            }
            catch {
                $module.FailJson("Failed setting agent job output file: $($_.Exception.Message)", $_)
            }
        }
    }

    if ($output) {
        # Convert to serializable first
        $resultData = ConvertTo-SerializableObject -InputObject $output

        # Add output file info to result data
        $resultData | Add-Member -MemberType NoteProperty -Name 'OutputFileInfo' -Value $(
            if ($null -ne $outputFile) { $outputFileResult } else { $null }
        ) -Force

        $module.Result.data = $resultData
    }
    $module.ExitJson()
}
catch {
    $module.FailJson("Error configuring SQL Agent job: $($_.Exception.Message)", $_)
}
