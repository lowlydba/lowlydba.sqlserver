#!/usr/bin/python
# -*- coding: utf-8 -*-

# (c) 2022, John McCall (@lowlydba)
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

DOCUMENTATION = r'''
---
module: tcp_port
short_description: Sets the TCP port for the instance
description:
  - Sets the TCP port for a SQL Server instance.
version_added: 0.10.0
options:
  username:
    description:
      - Username for alternative credential to authenticate with Windows.
    type: str
    required: false
  password:
    description:
      - Password for alternative credential to authenticate with Windows.
    type: str
    required: false
  port:
    description:
      - Port for SQL Server to listen on.
    type: int
    required: true
  ip_address:
    description:
      - IPv4 address.
    type: str
    required: false
notes:
  - Windows only.
author: "John McCall (@lowlydba)"
requirements:
  - L(dbatools,https://www.powershellgallery.com/packages/dbatools/) PowerShell module
extends_documentation_fragment:
  - lowlydba.sqlserver.sql_credentials
'''

EXAMPLES = r'''
- name: Set the default port
  lowlydba.sqlserver.tcp_port:
    sql_instance: sql-01.myco.io
    port: 1433

- name: Set a non-standard default port
  lowlydba.sqlserver.tcp_port:
    sql_instance: sql-01.myco.io
    port: 1933
'''

RETURN = r'''
data:
  description: Output from the C(Set-DbaTcpPort) function.
  returned: success, but not in check_mode.
  type: dict
'''
