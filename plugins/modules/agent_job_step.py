#!/usr/bin/python
# -*- coding: utf-8 -*-

# (c) 2022, John McCall (@lowlydba)
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

DOCUMENTATION = r'''
---
module: agent_job_step
short_description: Configures a SQL Agent job step.
description:
  - Configures a step for an agent job.
options:
  state:
    description:
      - Whether or not the job step should be C(present) or C(absent).
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
- name: Create a job step
  lowlydba.sqlserver.agent_job_step:
'''

RETURN = r'''
data:
  description: Output from the C(New-DbaAgentJobStep), C(Set-DbaAgentJobStep), or C(Remove-DbaAgentJobStep) function.
  returned: success
  type: dict
'''
