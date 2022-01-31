#!/usr/bin/python

# this is a windows documentation stub.  actual code lives in the .ps1
# file of the same name

DOCUMENTATION = '''
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
  max_memory:
    description:
      - The maximum memory in MB that the SQL Server instance can utilize. 0 will automatically calculate the ideal value.
    type: int
    required: false
    default: 0
author: "John McCall (@lowlydba)"
notes:
  - Check mode is supported.
'''

EXAMPLES = '''
- name: Automatically configure SQL max memory
  lowlydba.sqlserver.memory:
    sql_instance: sql-01.myco.io
'''
