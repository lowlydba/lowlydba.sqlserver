#!/usr/bin/python
# -*- coding: utf-8 -*-

# (c) 2022, John McCall (@lowlydba)
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

DOCUMENTATION = r'''
---
module: agent_job_category
short_description: Configures a SQL Agent job category.
description:
  - Creates if it doesn't exist, else does nothing.
options:
  category:
    description:
      - Name of the category.
    required: true
    type: str
  category_type:
    description:
      - The type of category. This can be C(LocalJob), C(MultiServerJob) or C(None).
        If no category is used all categories types will be removed.
    required: false
    type: str
    choices: ['LocalJob', 'MultiServerJob', 'None']
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
- name: Create a maintenance job category
  lowlydba.sqlserver.agent_job_category:
    sql_instance: sql-01.myco.io
    category: "Index Maintenance"
'''

RETURN = r'''
data:
  description: Output from the C(New-DbaAgentJobCategory) or C(Remove-DbaAgentJobCategory) function.
  returned: success
  type: dict
'''
