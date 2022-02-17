#!/usr/bin/python
# -*- coding: utf-8 -*-

# (c) 2022, John McCall (@lowlydba)
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

DOCUMENTATION = r'''
---
module: database
short_description: Creates and configures a database.
description:
     - Adds a new database to an existing SQL Server instance.
options:
  database:
    description:
      - Name of the target database.
    type: str
    required: true
  data_file_path:
    description:
      - Directory where the data and log files should be placed. Uses SQL Server's default if not supplied.
    type: str
    required: false
  owner_name:
    description:
      - Database owner login
    type: str
    required: false
    default: sa
  maxdop:
    description:
      - Integer MAXDOP value for the database.
    required: false
    type: int
    default: 0
  secondary_maxdop:
    description:
      - Integer MAXDOP value for the database when it is a non-primary replica in an availability group.
    required: false
    type: int
    default: 4
  compatibility_mode:
    description:
      - Compatibility mode for the database.
    required: false
    type: int
    default: 15
    choices: [13, 14, 15]
  rcsi:
    description:
      - Whether or not to enable Read Committed Snapshot Isolation.
    required: false
    type: bool
    default: true
  growth_type:
    description:
      - The measurement of the 'growth' parameter
    required: false
    type: str
    default: 'MB'
    choices: ['KB', 'MB', 'GB', 'TB']
  growth:
    description:
      - How large to auto grow database files in the chosen 'growth_type'.
    required: false
    type: int
  status:
    description:
      - Placeholder for future ability to add and drop a database.
    required: false
    type: str
    default: 'present'
    choices: ['present']
author: "John McCall (@lowlydba)"
notes:
  - Check mode is supported.
extends_documentation_fragment:
  - lowlydba.sqlserver.sql_credentials
'''

EXAMPLES = r'''
- name: Create Database
  lowlydba.sqlserver.database:
    sql_instance: sql-01.myco.io
    database_name: LowlyDB
'''
