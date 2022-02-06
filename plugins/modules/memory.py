#!/usr/bin/python
# -*- coding: utf-8 -*-

# (c) 2022, John McCall (@lowlydba)
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

DOCUMENTATION = r'''
---
module: memory
short_description: Sets the maximum memory for a SQL Server instance.
description:
     - Sets the maximum memory for a SQL Server instance.
options:
  sql_instance:
    description:
      - The SQL Server instance to modify.
    type: str
    required: true
  sql_username:
    description:
      - Username for SQL Authentication.
    type: str
    required: false
  sql_password:
    description:
      - Password for SQL Authentication.
    type: str
    required: false
  max:
    description:
      - The maximum memory in MB that the SQL Server instance can utilize. 0 will automatically calculate the ideal value.
    type: int
    required: false
    default: 0
author: "John McCall (@lowlydba)"
notes:
  - Check mode is supported.
'''

EXAMPLES = r'''
- name: Automatically configure SQL max memory
  lowlydba.sqlserver.memory:
    sql_instance: sql-01.myco.io
'''

RETURN = r'''
data:
  description: Raw output from the Set-DbaMaxMemory function.
  returned: success
  type: dict
'''
