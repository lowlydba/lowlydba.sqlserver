#!/usr/bin/python
# -*- coding: utf-8 -*-

# (c) 2022, John McCall (@lowlydba)
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

DOCUMENTATION = r'''
---
module: sa
short_description: Configure the 'sa' login for security best practices.
description:
  - Rename, disable, and reset the password for the 'sa' login on a SQL Server instance per best practices.
options:
  password:
    description:
      - Password for the login.
    type: str
    required: false
  new_name:
    description:
      - The new name to rename the sa login to.
    type: str
    required: false
  status:
    description:
      - Whether the login is C(enabled) or C(disabled).
    type: str
    required: false
    default: 'enabled'
    choices: ['enabled', 'disabled']
  password_must_change:
    description:
      - Enforces user must change password at next login.
        When specified will enforce C(password_expiration_enabled) and C(password_policy_enforced) as they are required.
    type: bool
    required: false
  password_policy_enforced:
    description:
      - Enforces password complexity policy.
    type: bool
    required: false
  password_expiration_enabled:
    description:
      - Enforces password expiration policy. Requires I(password_policy_enforced=true).
    type: bool
    required: false
version_added: 0.3.0
author: "John McCall (@lowlydba)"
requirements:
  - L(dbatools,https://www.powershellgallery.com/packages/dbatools/) PowerShell module
extends_documentation_fragment:
  - lowlydba.sqlserver.sql_credentials
'''

EXAMPLES = r'''
- name: Disable sa login
  lowlydba.sqlserver.sa:
    sql_instance: sql-01.myco.io
    disable: true

- name: Rename sa login
  lowlydba.sqlserver.sa:
    sql_instance: sql-01.myco.io
    new_name: 'notthesayourelookingfor'
'''
