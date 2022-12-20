#!/usr/bin/python
# -*- coding: utf-8 -*-

# (c) 2022, John McCall (@lowlydba)
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

DOCUMENTATION = r'''
---
module: role
short_description: Add or remove one or more roles for a given user in a specific database.
description:
  - Add or remove one or more roles for a given user in a specific database.
version_added: 1.4.0
options:
  username:
    description:
      - Name of the user
    type: str
    required: true
  database:
    description:
      - Database for the user
    type: str
    required: true
  roles:
    description:
      - Specifies a comma separated list of one or more roles to add or remove
    type: list
    elements: str
    required: false

author:
  - "Joe Krilov (@joey40)"
  - "John McCall (@lowlydba)"
requirements:
  - L(dbatools,https://www.powershellgallery.com/packages/dbatools/) PowerShell module
extends_documentation_fragment:
  - lowlydba.sqlserver.sql_credentials
  - lowlydba.sqlserver.attributes.check_mode
  - lowlydba.sqlserver.attributes.platform_all
  - lowlydba.sqlserver.state
'''

EXAMPLES = r'''
- name: Add a single role for a user
  lowlydba.sqlserver.role:
    sql_instance: sql-01.myco.io
    username: TheIntern
    database: InternProject1
    role: db_datareader

- name: Add multiple roles for a user
  lowlydba.sqlserver.role:
    sql_instance: sql-01.myco.io
    username: TheIntern
    database: InternProject1
    role: db_datareader, db_datawriter

- name: Remove roles for a user
  lowlydba.sqlserver.role:
    sql_instance: sql-01.myco.io
    username: TheIntern
    database: InternProject1
    role: db_datareader, db_datawriter
    state: absent
'''

RETURN = r'''
data:
  description: Output from the C(Add-DbaDbRoleMember), C(Get-DbaDbRoleMember), or C(Remove-DbaDbRoleMember) function.
  returned: success, but not in check_mode.
  type: dict
'''
