#!/usr/bin/python
# -*- coding: utf-8 -*-

# (c) 2022, John McCall (@lowlydba)
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

DOCUMENTATION = r'''
---
module: login
short_description: Configures a login for the target SQL Server instance.
description:
  - Creates, modifies, or removes a Windows or SQL Authentication login on a SQL Server instance.
options:
  login:
    description:
      - Name of the login to configure.
    type: str
    required: true
  password:
    description:
      - Password for the login, if SQL Authentication login.
    type: str
    required: false
  disable:
    description:
      - Whether or not to disable the login.
    type: bool
    required: false
  default_database:
    description:
      - Default database for the login.
    type: str
    required: false
  language:
    description:
      - Default language for the login.
    type: str
    required: false
  password_must_change:
    description:
      - Enforces user must change password at next login.
        When specified will enforce PasswordExpirationEnabled and PasswordPolicyEnforced as they are required for the must change.
    type: bool
    required: false
  password_policy_enforced:
    description:
      - Enforces password complexity policy.
    type: bool
    required: false
  password_expiration_enabled:
    description:
      - Enforces password expiration policy. Requires PasswordPolicyEnforced to be enabled.
    type: bool
    required: false
  state:
    description:
      - Whether or not the login should be C(present) or C(absent).
    required: false
    type: str
    default: 'present'
    choices: ['present', 'absent']
author: "John McCall (@lowlydba)"
extends_documentation_fragment:
  - lowlydba.sqlserver.sql_credentials
'''

EXAMPLES = r'''
- name:
  lowlydba.sqlserver.login:
    sql_instance: sql-01.myco.io
'''

RETURN = r'''
data:
  description: Raw output from the C(New-DbaLogin) or C(Set-DbaLogin) function.
  returned: success
  type: dict
'''
