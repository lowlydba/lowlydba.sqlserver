#!/usr/bin/python
# -*- coding: utf-8 -*-

# (c) 2022, John McCall (@lowlydba)
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

DOCUMENTATION = r'''
---
module: agent_job
short_description: Configures a SQL Agent job.
description:
  - Configure a SQL Agent job, including which schedules and category it belongs to.
options:
  job:
    description:
      - The name of the target SQL Agent job.
    type: str
    required: true
  description:
    description:
      - Description for the SQL Agent job.
    type: str
    required: false
  category:
    description:
      - Category for the target SQL Agent job. Must already exist.
    type: str
    required: false
  status:
    description:
      - Whether the SQL Agent job should be C(enabled) or C(disabled).
    type: str
    required: false
    default: 'enabled'
    choices: ['enabled', 'disabled']
  owner_login:
    description:
      - The owning login for the database. Will default to the current user if
        the database is being created and none supplied.
    type: str
    required: false
  start_step_id:
    description:
      - What step number the job should begin with when run.
    type: int
    required: false
  schedule:
    description:
      - The name of the schedule the job should be associated with. Only one schedule per job is supported.
    type: str
    required: false
  force:
    description:
      - If this switch is enabled, any job categories will be created if they don't exist already.
    type: bool
    default: false
  state:
    description:
      - Whether or not the job should be C(present) or C(absent).
    required: false
    type: str
    default: 'present'
    choices: ['present', 'absent']
author: "John McCall (@lowlydba)"
notes:
  - Check mode is supported.
  - On slower hardware, stale job component data may be returned (i.e., a previous or default job category).
    Configuring each component (schedule, step, category, etc.) individually is recommended for this reason.
extends_documentation_fragment:
  - lowlydba.sqlserver.sql_credentials
'''

EXAMPLES = r'''
- name: Create a job schedule
  lowlydba.sqlserver.agent_job:
'''

RETURN = r'''
data:
  description: Output from the C(New-DbaAgentJob), C(Set-DbaAgentJob), or C(Remove-DbaAgentJob) function.
  returned: success, but not in check_mode.
  type: dict
'''
