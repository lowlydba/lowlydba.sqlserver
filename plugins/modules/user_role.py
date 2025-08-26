#!/usr/bin/python
# -*- coding: utf-8 -*-

# (c) 2022, John McCall (@lowlydba)
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

DOCUMENTATION = r'''
---
module: user_role
short_description: Configures a user's role in a database.
description:
  - Adds or removes a user's role in a database.
version_added: 2.4.0
options:
  database:
    description:
      - Database for the user.
    type: str
    required: true
  username:
    description:
      - Name of the user.
    type: str
    required: true
  role:
    description:
      - The database role for the user to be modified.
      - When used with State set to present, will add the user to this role.
      - When used with State set to absent, will remove the user from this role.
      - Mutually exclusive with roles
    type: str
  roles:
    description:
      - The database roles for the user to be added, removed or set.
      - Mutually exclusive with role
    type: dict
    suboptions:
      add:
        description:
          - Adds the user to the specified roles, keeping the
            existing role membership if they are not specified.
        type: list
        elements: str
      remove:
        description:
          - Removes the user from the specified roles, keeping the
            existing role membership if they are not specified.
        type: list
        elements: str
      set:
        description:
          - Adds the user to the specified roles.
          - User will be removed from any other roles not specified.
          - Set this to an empty list to remove all members from a group..
        type: list
        elements: str
    version_added: 2.6.2
author: "John McCall (@lowlydba)"
requirements:
  - L(dbatools,https://www.powershellgallery.com/packages/dbatools/) PowerShell module
extends_documentation_fragment:
  - lowlydba.sqlserver.sql_credentials
  - lowlydba.sqlserver.attributes.check_mode
  - lowlydba.sqlserver.attributes.platform_all
  - lowlydba.sqlserver.state
'''

EXAMPLES = r'''
- name: Add a user to a fixed db role
  lowlydba.sqlserver.user_role:
    sql_instance: sql-01.myco.io
    username: TheIntern
    database: InternProject1
    role: db_owner

- name: Add a user to a list of db roles
  lowlydba.sqlserver.user_role:
    sql_instance: sql-01.myco.io
    username: TheIntern
    database: InternProject1
    roles:
      add:
        - db_datareader
        - db_datawriter

- name: Remove a user from a fixed db role
  lowlydba.sqlserver.user_role:
    sql_instance: sql-01.myco.io
    username: TheIntern
    database: InternProject1
    role: db_owner
    state: absent

- name: Add a user to a custom db role
  lowlydba.sqlserver.user_role:
    sql_instance: sql-01.myco.io
    username: TheIntern
    database: InternProject1
    role: db_intern
    state: present

- name: Specify a list of roles that user should be in and remove all others
  lowlydba.sqlserver.user_role:
    sql_instance: sql-01.myco.io
    username: TheIntern
    database: InternProject1
    roles:
      set:
        - db_datareader
        - db_datawriter
    state: present

- name: Remove user from all roles on this database
  lowlydba.sqlserver.user_role:
    sql_instance: sql-01.myco.io
    username: TheIntern
    database: InternProject1
    roles:
      set: []
    state: present
'''

RETURN = r'''
data:
  description:
    - If called with role, then data is output from the C(Remove-DbaDbRoleMember), (Get-DbaDbRoleMember), or C(Add-DbaDbRoleMember) functions.
    - If called with roles, then data returned roleMembership, which is an array of roles that the user is now a member of.
    - If called without either role or roles, then data returned is roleMembership which is users current list of roles.
  returned: success, but not in check_mode.
  type: dict
'''
