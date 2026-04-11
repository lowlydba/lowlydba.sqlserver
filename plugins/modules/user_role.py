#!/usr/bin/python
# -*- coding: utf-8 -*-

# (c) 2026, John McCall (@lowlydba)
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

DOCUMENTATION = r'''
---
module: user_role
short_description: Configures a user's role in a database.
description:
  - Adds or removes a user's role in a database.
  - Use the I(roles) option to work with multiple roles at once using the add/remove/set pattern.
version_added: "2.4.0"
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
  roles:
    description:
      - A dictionary of roles to manage for the user.
      - Supports three keys C(add), C(remove), and C(set).
      - C(add) adds the user to the specified roles. An empty list is a no-op and returns current membership.
      - C(remove) removes the user from the specified roles. An empty list is a no-op and returns current membership.
      - C(set) replaces all current roles with the specified roles. An empty list removes all role memberships.
      - C(set) cannot be combined with C(add) or C(remove).
      - At least one key must be present.
    type: dict
    required: false
    version_added: "2.8.0"
    suboptions:
      add:
        description:
          - A list of role names to add the user to. May be empty to query current membership without changes.
        type: list
        elements: str
      remove:
        description:
          - A list of role names to remove the user from. May be empty to query current membership without changes.
        type: list
        elements: str
      set:
        description:
          - A list of role names that replaces the user's current roles. An empty list removes all role memberships.
        type: list
        elements: str
  role:
    description:
      - The database role for the user to be modified.
      - "B(Deprecated:) This parameter is deprecated and will be removed in version 3.0.0. Use I(roles) instead."
    type: str
    required: false
  state:
    description:
      - Desired state of the user role membership.
      - "Only applicable when using the I(role) parameter (legacy mode). Cannot be used with I(roles)."
    type: str
    choices:
      - present
      - absent
author: "John McCall (@lowlydba)"
requirements:
  - L(dbatools,https://www.powershellgallery.com/packages/dbatools/) PowerShell module
extends_documentation_fragment:
  - lowlydba.sqlserver.sql_credentials
  - lowlydba.sqlserver.attributes.check_mode
  - lowlydba.sqlserver.attributes.platform_all
'''

EXAMPLES = r'''
- name: Add a user to a fixed db role (legacy)
  lowlydba.sqlserver.user_role:
    sql_instance: sql-01.myco.io
    username: TheIntern
    database: InternProject1
    role: db_owner

- name: Remove a user from a fixed db role (legacy)
  lowlydba.sqlserver.user_role:
    sql_instance: sql-01.myco.io
    username: TheIntern
    database: InternProject1
    role: db_owner
    state: absent

- name: Add user to multiple roles
  lowlydba.sqlserver.user_role:
    sql_instance: sql-01.myco.io
    username: TheIntern
    database: InternProject1
    roles:
      add:
        - db_owner
        - db_datareader

- name: Remove user from multiple roles
  lowlydba.sqlserver.user_role:
    sql_instance: sql-01.myco.io
    username: TheIntern
    database: InternProject1
    roles:
      remove:
        - db_owner
        - db_datareader

- name: Set user's roles (replace all current roles)
  lowlydba.sqlserver.user_role:
    sql_instance: sql-01.myco.io
    username: TheIntern
    database: InternProject1
    roles:
      set:
        - db_datareader
        - db_datawriter

- name: Combine add and remove operations
  lowlydba.sqlserver.user_role:
    sql_instance: sql-01.myco.io
    username: TheIntern
    database: InternProject1
    roles:
      add:
        - db_securityadmin
      remove:
        - db_owner
'''

RETURN = r'''
data:
  description:
    - For the C(roles) parameter - a summary object containing current role membership and any roles added or removed.
    - For the legacy C(role) parameter - output from C(Add-DbaDbRoleMember) or C(Remove-DbaDbRoleMember). Not returned in check_mode.
  returned: success
  type: dict
  contains:
    roleMembership:
      description: List of roles the user is currently a member of. In check_mode reflects state before any changes.
      type: list
      sample: ["db_owner", "db_datareader"]
    added:
      description: List of roles that were added (or would be added in check_mode).
      type: list
      elements: str
    removed:
      description: List of roles that were removed (or would be removed in check_mode).
      type: list
      elements: str
'''
