#!/usr/bin/python
# -*- coding: utf-8 -*-

# (c) 2022, John McCall (@lowlydba)
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

DOCUMENTATION = r'''
---
module: agent_job_schedule
short_description: Configures a SQL Agent job schedule.
description:
  - Configures settings for an agent schedule that can be applied to one or more agent jobs.
options:
  schedule:
    description:
      - The name of the schedule.
    type: str
    required: true
  job:
    description:
      - The name of the job that has the schedule.
      - Schedules and jobs can also be associated via agent_job.
      - See https://docs.dbatools.io/New-DbaAgentSchedule for more detailed usage.
    type: str
  status:
    description:
      - Whether the schedule is C(Enabled) or C(Disabled).
    type: str
    default: 'Enabled'
    choices: ['Enabled', 'Disabled']
  force:
    description:
      - The force parameter will ignore some errors in the parameters and assume defaults.
        It will also remove the any present schedules with the same name for the specific job.
        If force is used the default will be 'Once'.
    type: bool
  frequency_type:
    description:
      - A value indicating when a job is to be executed.
    type: str
    required: false
    choices: ['Once', 'OneTime', 'Daily', 'Weekly', 'Monthly', 'MonthlyRelative', 'AgentStart', 'AutoStart', 'IdleComputer', 'OnIdle']
  frequency_interval:
    description:
      - The days that a job is executed.
        Allowed values for frequency_type 'Daily' - EveryDay or a number between 1 and 365.
        Allowed values for frequency_type 'Weekly' - Sunday, Monday, Tuesday, Wednesday, Thursday, Friday, Saturday, Weekdays, Weekend or EveryDay.
        Allowed values for frequency_type 'Monthly' - Numbers 1 to 31 for each day of the month.
        If "Weekdays", "Weekend" or "EveryDay" is used it over writes any other value that has been passed before.
        If force is used the default will be 1.
    type: str
    required: false
  frequency_subday_type:
    description:
      - Specifies the units for the subday frequency_interval.
    type: str
    required: false
    choices: ['Time', 'Seconds', 'Minutes', 'Hours']
  frequency_subday_interval:
    description:
      - The number of subday type periods to occur between each execution of a job.
    type: int
    required: false
  frequency_relative_interval:
    description:
      - A job's occurrence of frequency_interval in each month, if frequency_interval is 32 ('MonthlyRelative').
    type: str
    required: false
    choices: ['Unused', 'First', 'Second', 'Third', 'Fourth', 'Last']
  frequency_recurrence_factor:
    description:
      - The number of weeks or months between the scheduled execution of a job.
        Used only if frequency_type is 'Weekly', 'Monthly' or 'MonthlyRelative'.
    type: int
    required: false
  start_date:
    description:
      - The date on which execution of a job can begin.
        If force is used the start date will be the current day.
    type: str
    required: false
  end_date:
    description:
      - The date on which execution of a job can stop.
        If force is used the end date will be '9999-12-31'
    type: str
    required: false
  start_time:
    description:
      - The time on any day to begin execution of a job. Format HHMMSS / 24 hour clock.
      - If force is used the start time will be '00:00:00'
    type: str
    required: false
  end_time:
    description:
      - The time on any day to end execution of a job. Format HHMMSS / 24 hour clock.
        If force is used the start time will be '23:59:59'
    type: str
    required: false
  state:
    description:
      - Whether or not the job category should be C(present) or C(absent).
    required: false
    type: str
    default: 'present'
    choices: ['present', 'absent']
author: "John McCall (@lowlydba)"
notes:
  - Check mode is supported.
extends_documentation_fragment:
  - lowlydba.sqlserver.sql_credentials
'''

EXAMPLES = r'''
- name: Create a job schedule
  lowlydba.sqlserver.agent_job_schedule:
    sql_instance: sql-01.myco.io
    schedule: Daily
    force: true
    status: Enabled
    start_date: 2020-05-25  # May 25, 2020
    end_date: 2099-05-25    # May 25, 2099
    start_time: 010500      # 01:05:00 AM
    end_time: 140030        # 02:00:30 PM
    state: present
'''

RETURN = r'''
data:
  description: Output from the C(New-DbaAgentJobSchedule) or C(Remove-DbaAgentJobSchedule) function.
  returned: success
  type: dict
'''
