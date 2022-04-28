================================
lowlydba.sqlserver Release Notes
================================

.. contents:: Topics


v0.4.0
======

Release Summary
---------------

Two new AlwaysOn modules and a few consistency fixes!

Minor Changes
-------------

- Test for 'Name' property for sa module after dbatools release 1.1.87 standardizes command outputs. (https://github.com/dataplat/dbatools/releases/tag/v1.1.87)

Breaking Changes / Porting Guide
--------------------------------

- All modules should use a bool 'enabled' instead of a string 'status' to control object state.

New Modules
-----------

- availability_group - Configures availability group(s).
- hadr - Enable or disable HADR.

v0.3.0
======

Release Summary
---------------

New sa module and fixes for login related modules.

Minor Changes
-------------

- Fix logic to properly pass password policy options to function in the login module.

New Modules
-----------

- sa - Configure the 'sa' login for security best practices.

v0.2.0
======

Release Summary
---------------

Code cleanup, testing improvements, new _info module!

Minor Changes
-------------

- Add DbaTools module requirement to documentation and fix missing examples. (https://github.com/lowlydba/lowlydba.sqlserver/pull/47)
- Utilize PowerShell Requires for dbatools min version needs instead of custom function. Consolidate/standardize credential setup and serialization. (https://github.com/lowlydba/lowlydba.sqlserver/pull/48)

New Modules
-----------

- instance_info - Returns basic information for a SQL Server instance.

v0.1.1
======

Release Summary
---------------

Add database tag for Galaxy

v0.1.0
======

Release Summary
---------------

It's a release! First version to publish to Ansible Galaxy.

New Modules
-----------

- agent_job - Configures a SQL Agent job.
- agent_job_category - Configures a SQL Agent job category.
- agent_job_schedule - Configures a SQL Agent job schedule.
- agent_job_step - Configures a SQL Agent job step.
- database - Creates and configures a database.
- login - Configures a login for the target SQL Server instance.
- maintenance_solution - Install/update Maintenance Solution
- memory - Sets the maximum memory for a SQL Server instance.
- nonquery - Executes a generic nonquery.
- resource_governor - Configures the resource governor on a SQL Server instance.
- rg_resource_pool - Configures a resource pool for use by the Resource Governor.
- rg_workload_group - Configures a workload group for use by the Resource Governor.
- sp_configure - Make instance level system configuration changes via sp_configure.
- sp_whoisactive - Install/update sp_whoisactive by Adam Mechanic.
- traceflag - Enable or disable global trace flags on a SQL  Server instance.
