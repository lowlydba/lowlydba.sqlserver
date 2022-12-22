#!/usr/bin/python
# -*- coding: utf-8 -*-

# (c) 2022, John McCall (@lowlydba)
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

DOCUMENTATION = r'''
---
module: role_member_info
short_description: Returns basic information about a role or roles
description:
  - Returns basic information about a role or roles.
version_added: 1.4.0
options:
  username:
    description:
      - Name of the user
    type: str
    required: false
  database:
    description:
      - Database for the user
    type: str
    required: false
  roles:
    description:
      - Specifies a comma separated list of one or more roles
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
  - lowlydba.sqlserver.attributes.check_mode_read_only
  - lowlydba.sqlserver.attributes.platform_all
'''

EXAMPLES = r'''
- name: Return member of the db_datareader and db_datawriter role on the 'InternProject1' DB
  lowlydba.sqlserver.role_member_info:
    sql_instance: sql-01.myco.io
    database: InternProject1
    role: db_datareader, db_datawriter


- name: Return all roles for user 'TheIntern' on the 'InternProject1' DB
  lowlydba.sqlserver.role_member_info:
    sql_instance: sql-01.myco.io
    username: TheIntern
    database: InternProject1
'''

RETURN = r'''
data:
  description: Output from the C(Get-DbaDbRoleMember) function.
  returned: always
  type: dict
'''
