#!/usr/bin/python
# -*- coding: utf-8 -*-

# (c) 2022, John McCall (@lowlydba)
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

DOCUMENTATION = r'''
---
module: rg_resource_pool
short_description: Configures a resource pool for use by the Resource Governor.
description:
     - Creates or modifies a resource pool to be used by the Resource Governor. Default values are handled by the Powershell functions themselves.
options:
  resource_pool:
    description:
      - Name of the target resource pool.
    type: str
    required: true
  type:
    description:
      - Specify the type of resource pool.
    type: str
    required: false
    choices: ['Internal', 'External']
  max_cpu_perc:
    description:
      - Maximum CPU Percentage able to be used by queries in this resource pool.
    type: int
    required: false
  min_cpu_perc:
    description:
      - Minimum CPU Percentage able to be used by queries in this resource pool.
    type: int
    required: false
  cap_cpu_perc:
    description:
      - Cap CPU Percentage able to be used by queries in this resource pool.
    type: int
    required: false
  max_mem_perc:
    description:
      - Maximum Memory Percentage able to be used by queries in this resource pool.
    type: int
    required: false
  min_mem_perc:
    description:
      - Minimum Memory Percentage able to be used by queries in this resource pool.
    type: int
    required: false
  max_iops_per_vol:
    description:
      - Maximum IOPS/volume able to be used by queries in this resource pool.
    type: int
    required: false
  min_iops_per_vol:
    description:
      - Minimum IOPS/volume able to be used by queries in this resource pool.
    type: int
    required: false
  state:
    description:
      - Whether or not the resource pool should be C(present) or C(absent).
    required: false
    type: str
    default: 'present'
    choices: ['present', 'absent']
author: "John McCall (@lowlydba)"
extends_documentation_fragment:
  - lowlydba.sqlserver.sql_credentials
'''

EXAMPLES = r'''
- name: Create rg resource pool
  lowlydba.sqlserver.rg_resource_pool:
    sql_instance: sql-01.myco.io
'''

RETURN = r'''
data:
  description: Raw output from the C(Set-DbaRgResourcePool), C(New-DbaRgResourcePool), or C(Remove-DbaRgResourcePool) function.
  returned: success
  type: dict
'''
