#!/usr/bin/python
# -*- coding: utf-8 -*-

# (c) 2022, John McCall (@lowlydba)
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

DOCUMENTATION = r'''
---
module: ag_replica
short_description: Configures an availability group replica.
description:
     - Configures an availability group replica.
options:
  sql_instance_replica:
    description:
      - The SQL Server instance where of the replica to be configured.
    type: str
    required: true
  sql_instance_primary:
    description:
      - The primary SQL Server instance for the Availability Group. Used to lookup metadata for easier joining of a new replica.
    type: str
    required: true
  ag_name:
    description:
      - Name of the Availability Group that will have the new replica joined to it.
    type: str
    required: true
  failover_mode:
    description:
      - Whether the replica have Automatic or Manual failover.
    type: str
    required: false
    default: 'Manual'
    choices: ['Automatic', 'Manual']
  availability_mode:
    description:
      - Whether the replica should be Asynchronous or Synchronous.
    type: str
    required: false
    default: 'AsynchronousCommit'
    choices: ['AsynchronousCommit', 'SynchronousCommit']
  seeding_mode:
    description:
      - Default seeding mode for the replica. Should remain as the default otherwise manual setup may be required.
    type: str
    required: false
    default: 'Automatic'
    choices: ['Automatic', 'Manual']
  connection_mode_in_primary_role:
    description:
        - Which connections can be made to the database when it is in the primary role.
    type: str
    required: false
    default: 'AllowAllConnections'
    choices: ['AllowReadIntentConnectionsOnly','AllowAllConnections']
  connection_mode_in_secondary_role:
    description:
      - Which connections can be made to the database when it is in the secondary role.
    type: str
    required: false
    default: 'AllowNoConnections'
    choices: ['AllowNoConnections','AllowReadIntentConnectionsOnly','AllowAllConnections']
  read_only_routing_connection_url:
    description:
      - Sets the read only routing connection url for the availability replica.
    type: str
    required: false
  read_only_routing_list:
    description:
      - Sets the read only routing ordered list of replica server names to use when redirecting read-only connections through this availability replica.
    type: str
    required: false
author: "John McCall (@lowlydba)"
requirements:
  - L(dbatools,https://www.powershellgallery.com/packages/dbatools/) PowerShell module
extends_documentation_fragment:
  - lowlydba.sqlserver.sql_credentials
  - lowlydba.sqlserver.state
'''

EXAMPLES = r'''
- name: Add a DR replica
  lowlydba.sqlserver.ag_replica:
    ag_name: 'agMyDatabase'
    sql_instance_primary: sql-01.myco.io
    sql_instance_replica: sql-02.myco.io
    failover_mode: 'Manual'
    availability_mode: 'Asynchronous'
    seeding_mode: 'Automatic'
    connection_mode_in_primary_role: 'AllowAllConnections'
    connection_mode_in_secondary_role: 'AllowNoConnections'
'''
