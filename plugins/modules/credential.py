#!/usr/bin/python
# -*- coding: utf-8 -*-

# (c) 2022, John McCall (@lowlydba)
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

DOCUMENTATION = r'''
---
module: credential
short_description: Configures a credential on a SQL server
description:
  - Creates, replaces, or removes a credential on a SQL server.
version_added: 1.3.0
options:
  identity:
    description:
      - The Credential Identity.
    type: str
    required: true
  name:
    description:
      - The Credential name.
    type: str
    required: false
  secure_password:
    description:
      - Secure string used to authenticate the Credential Identity.
    type: str
    required: false
  mapped_class_type:
    description:
      - Sets the class associated with the credential.
    type: str
    required: false
    choices: ['CryptographicProvider','None']
  provider_name:
    description:
      - Sets the name of the provider.
    type: str
    required: false
  force:
    description:
      - If this switch is enabled, the existing credential will be dropped and recreated.
    type: bool
    default: false
author:
  - "Joe Krilov (@Joey40)"
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
- name: Create a credential with a password
  lowlydba.sqlserver.credential:
    sql_instance: sql-01.myco.io
    identity: ad\\user
    name: MyCredential
    secure_password : <Password>

- name: Replace an existing credential
  lowlydba.sqlserver.credential:
    sql_instance: sql-01.myco.io
    identity: MyIdentity
    force: true

- name: Create a credential using a SAS token for a backup URL
  lowlydba.sqlserver.credential:
    sql_instance: sql-01.myco.io
    identity: SHARED ACCESS SIGNATURE
    name: https://<azure storage account name>.blob.core.windows.net/<blob container>
    secure_password : <Shared Access Token>

- name: Remove a credential
  lowlydba.sqlserver.credential:
    sql_instance: sql-01.myco.io
    identity: MyIdentity
    state: absent
'''

RETURN = r'''
data:
  description: Output from the C(New-DbaDbCredential), C(Get-DbaDbCredential), or C(Remove-DbaDbCredential) function.
  returned: success, but not in check_mode.
  type: dict
'''
