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
  recovery_model:
    description:
      - Choose the recovery model for the database.
    type: str
    required: false
    choices: ['Full', 'Simple', 'BulkLogged']
  data_file_path:
    description:
      - Directory where the data files should be placed. Uses SQL Server's default if not supplied.
        Only used if database is being created.
    type: str
    required: false
  log_file_path:
    description:
      - Directory where the log files should be placed. Uses SQL Server's default if not supplied.
        Only used if database is being created.
    type: str
    required: false
  owner:
    description:
      - Database owner login.
    type: str
    required: false
  maxdop:
    description:
      - MAXDOP value for the database.
    required: false
    type: int
  secondary_maxdop:
    description:
      - MAXDOP value for the database when it is a non-primary replica in an availability group.
    required: false
    type: int
  compatibility:
    description:
      - Compatibility mode for the database. Follows the format of "Version90", "Version100", and so on.
        String is validated by C(Set-DbaDbCompatibility).
    required: false
    type: str
  rcsi:
    description:
      - Whether or not to enable Read Committed Snapshot Isolation.
    required: false
    type: bool
  state:
    description:
      - Whether or not the database should be C(present) or C(absent).
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
- name: Create Database
  lowlydba.sqlserver.database:
    sql_instance: sql-01.myco.io
    database_name: LowlyDB
'''

RETURN = r'''
data:
  description: Modified output from the C(New-DbaDatabase), C(Set-DbaDatabase), or C(Remove-DbaDatabase) function.
  returned: success, but not in check_mode.
  type: dict
'''
