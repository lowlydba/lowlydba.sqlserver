#!/usr/bin/python
# -*- coding: utf-8 -*-

# (c) 2022, John McCall (@lowlydba)
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

DOCUMENTATION = r'''
---
module: spn
short_description: Configures SPNs for SQL Server
description:
  - Configures SPNs for SQL Server.
version_added: 0.6.0
options:
  computer_username:
    description:
      - Username of a credential to connect to Active Directory with.
    type: str
    required: false
  computer_password:
    description:
      - Password of a credential to connect to Active Directory with.
    type: str
    required: false
  computer:
    description:
      - The host or alias to configure the SPN for. Can include the port in the format C(host:port).
    type: str
    required: true
  service_account:
    description:
      - The account you want the SPN added to. Will be looked up if not provided.
    type: str
    required: true
author: "John McCall (@lowlydba)"
requirements:
  - L(dbatools,https://www.powershellgallery.com/packages/dbatools/) PowerShell module
extends_documentation_fragment:
  - lowlydba.sqlserver.state
  - lowlydba.sqlserver.attributes.check_mode
  - lowlydba.sqlserver.attributes.platform_win
'''

EXAMPLES = r'''
- name: Add a server SPN
  lowlydba.sqlserver.spn:
    computer: sql01.example.com
    service_account: EXAMPLE\sql-svc

- name: Add an SPN for an availability group listener
  lowlydba.sqlserver.spn:
    computer: AG-App.example.com:1433
    service_account: EXAMPLE\sql-svc
'''

RETURN = r'''
data:
  description: Output from the C(Set-DbaSpn) or C(Remove-DbaSpn) function.
  returned: success, but not in check_mode.
  type: dict
'''
