#!/usr/bin/python
# -*- coding: utf-8 -*-

# (c) 2022, John McCall (@lowlydba)
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

DOCUMENTATION = r'''
---
module: query
short_description: Executes a generic query.
description:
     - Execute a query against a database. Does not return a resultset. Ideal for ad-hoc configurations or DML queries.
options:
  sql_instance:
    description:
      - The SQL Server instance to target.
    type: str
    required: true
  sql_username:
    description:
      - Username for SQL Authentication.
    type: str
    required: false
  sql_password:
    description:
      - Password for SQL Authentication.
    type: str
    required: false
  database:
    description:
      - Name of the database to execute the query in.
    type: str
    required: true
  query:
    description:
      - The query to be executed.
    type: str
    required: true
  query_timeout:
    description:
      - Number of seconds to wait before timing out the query execution.
    type: int
    required: false
    default: 60
author: "John McCall (@lowlydba)"
notes:
  - Check mode is supported, but the query will not be parsed.
'''

EXAMPLES = r'''
- name: Update a table value
  lowlydba.sqlserver.query:
    sql_instance: sql-01-myco.io
    database: userdb
    query: "UPDATE dbo.User set IsActive = 1;"
'''

RETURN = r''' # '''
