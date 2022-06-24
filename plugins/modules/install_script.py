#!/usr/bin/python
# -*- coding: utf-8 -*-

# (c) 2022, John McCall (@lowlydba)
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

DOCUMENTATION = r'''
---
module: migrate_database
short_description: Runs migration scripts against a database.
description:
     - Uses DBOps to run C(Dbo-InstallScript) against a target SQL Server database.
options:
  database:
    description:
      - Name of the target database.
    required: true
  path:
    description:
      - Directory where targeted sql scripts are stored.
    type: str
    required: true
author: "John McCall (@lowlydba)"
requirements:
  - L(dbatools,https://www.powershellgallery.com/packages/dbatools/) PowerShell module
  - L(dbops,https://github.com/dataplat/dbops) PowerShell module
extends_documentation_fragment:
  - lowlydba.sqlserver.sql_credentials
'''

EXAMPLES = '''
- name: Migrate a database
  migrate_database:
    sql_instance: test-server.my.company.com
    database_name: AdventureWorks
    path: migrations
'''

RETURN = r'''
data:
  description: Modified output from the C(Install-DboScript) function.
  returned: success, but not in check_mode.
  type: dict
'''
