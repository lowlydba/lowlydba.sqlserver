#!powershell
# -*- coding: utf-8 -*-

# (c) 2022, John McCall (@lowlydba)
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -CSharpUtil Ansible.Basic
#AnsibleRequires -PowerShell ansible_collections.lowlydba.sqlserver.plugins.module_utils._SqlServerUtils
#Requires -Modules @{ ModuleName="dbatools"; ModuleVersion="1.1.87" }

$ErrorActionPreference = "Stop"

$spec = @{
    supports_check_mode = $true
    options = @{
        sql_instance_replica = @{type = 'str'; required = $true }
        sql_instance_primary = @{type = 'str'; required = $true }
        ag_name = @{type = 'str'; required = $true }
        failover_mode = @{
            type = 'str';
            required = $false;
            default = 'Manual';
            choices = @('Manual', 'Automatic')
        }
        availability_mode = @{
            type = 'str';
            required = $false; default = 'AsynchronousCommit';
            choices = @('SynchronousCommit', 'AsynchronousCommit')
        }
        seeding_mode = @{
            type = 'str';
            required = $false;
            default = 'Automatic';
            choices = @('Manual', 'Automatic')
        }
        connection_mode_in_primary_role = @{
            type = 'str';
            required = $false;
            default = 'AllowAllConnections';
            choices = @('AllowReadIntentConnectionsOnly', 'AllowAllConnections')
        }
        connection_mode_in_secondary_role = @{
            type = 'str';
            required = $false;
            default = 'AllowNoConnections';
            choices = @('AllowNoConnections', 'AllowReadIntentConnectionsOnly', 'AllowAllConnections')
        }
        read_only_routing_connection_url = @{
            type = 'str';
            required = $false;
        }
        read_only_routing_list = @{
            type = 'str';
            required = $false;
        }
        state = @{type = "str"; required = $false; default = "present"; choices = @("present", "absent") }
    }
}
$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec, @(Get-LowlyDbaSqlServerAuthSpec))
$sqlInstance, $sqlCredential = Get-SqlCredential -Module $module
$readOnlyRoutingConnectionUrl = $module.params.read_only_routing_connection_url
$readOnlyRoutingList = $module.Params.read_only_routing_list
$object = @{
    SqlInstance = $sqlInstance
    SqlCredential = $sqlCredential
    Replica = $module.Params.sql_instance_replica
    AvailabilityGroup = $module.Params.ag_name
    FailoverMode = $module.Params.failover_mode
    SeedingMode = $module.Params.seeding_mode
    AvailabilityMode = $module.Params.availability_mode
    ConnectionModeInPrimaryRole = $module.Params.connection_mode_in_primary_role
    ConnectionModeInSecondaryRole = $module.Params.connection_mode_in_secondary_role
}
$ReplicaNameShort = $object.Replica.Split('.')[0]
$AvailabilityModeTSQL = switch ($module.Params.availability_mode) {
    "AsynchronousCommit" { "ASYNCHRONOUS_COMMIT" }
    "SynchronousCommit" { "SYNCHRONOUS_COMMIT" }
    default { $module.Params.availability_mode }
}
$ConnectionModeInSecondaryRoleTSQL = switch ($module.Params.connection_mode_in_secondary_role) {
    "AllowNoConnections" { "NO" }
    "AllowReadIntentConnectionsOnly" { "READ_ONLY" }
    "AllowAllConnections" { "YES" }
    default { $module.Params.connection_mode_in_secondary_role }
}

$module.Result.changed = $false

try {
    # Add a new replica
    $existingReplica = Get-DbaAgReplica -SqlInstance $object.Replica -AvailabilityGroup $object.AvailabilityGroup -Replica $ReplicaNameShort -EnableException
    if ($null -eq $existingReplica) {
        # Doing the replica add via SMO results in a high failure rate for auto seeding - T-SQL works a lot more reliably
        # Might be worth revisiting this later
        $svcAcct = (Get-DbaService -ComputerName $object.Replica -Type "Engine").StartName
        $addReplicaQuery1 = "IF (SELECT state FROM sys.endpoints WHERE name = N'Hadr_endpoint') <> 0
		BEGIN
			ALTER ENDPOINT [Hadr_endpoint] STATE = STARTED
		END
		GO

		GRANT CONNECT ON ENDPOINT::[Hadr_endpoint] TO [$svcAcct]
		GO

		IF EXISTS(SELECT * FROM sys.server_event_sessions WHERE name='AlwaysOn_health')
		BEGIN
			ALTER EVENT SESSION [AlwaysOn_health] ON SERVER WITH (STARTUP_STATE=ON);
		END
		IF NOT EXISTS(SELECT * FROM sys.dm_xe_sessions WHERE name='AlwaysOn_health')
		BEGIN
			ALTER EVENT SESSION [AlwaysOn_health] ON SERVER STATE=START;
		END
		GO"
        $addReplicaQuery2 = "ALTER AVAILABILITY GROUP [$($object.AvailabilityGroup)]
		ADD REPLICA ON N'$ReplicaNameShort' WITH (ENDPOINT_URL = N'TCP://$($object.Replica):5022',
            FAILOVER_MODE = $($object.FailoverMode), AVAILABILITY_MODE = $AvailabilityModeTSQL, BACKUP_PRIORITY = $($object.BackupPriority),
            SEEDING_MODE = $($object.SeedingMode), SECONDARY_ROLE(ALLOW_CONNECTIONS = $ConnectionModeInSecondaryRoleTSQL));"
        $addReplicaQuery3 = "ALTER AVAILABILITY GROUP [$($object.AvailabilityGroup)] JOIN;
		GO
		ALTER AVAILABILITY GROUP [$($object.AvailabilityGroup)] GRANT CREATE ANY DATABASE;
		GO"
        if (-not($module.CheckMode)) {
            Invoke-DbaQuery -SqlInstance $object.Replica -Query $addReplicaQuery1 -Database master -EnableException | Out-Null
            Invoke-DbaQuery -SqlInstance $object.SqlInstance -Query $addReplicaQuery2 -Database master -EnableException | Out-Null
            Invoke-DbaQuery -SqlInstance $object.Replica -Query $addReplicaQuery3 -Database master -EnableException | Out-Null
            $module.Result.changed = $true
        }
    }
    # Configure existing replica(s)
    else {
        $compareReplicaProperty = @(
            'AvailabilityMode'
            'FailoverMode'
            'ConnectionModeInPrimaryRole'
            'ConnectionModeInSecondaryRole'
            'SeedingMode'
        )
        $existingReplica = Get-DbaAgReplica -SqlInstance $sqlInstance -AvailabilityGroup $object.AvailabilityGroup -Replica $ReplicaNameShort -EnableException

        # Configure the replica
        foreach ($replica in $existingReplica) {
            $replicaDiff = Compare-Object -ReferenceObject $object -DifferenceObject $replica -Property $compareReplicaProperty
            if ($replicaDiff) {
                $setReplicaParams = @{
                    SqlInstance = $object.SqlInstance
                    Replica = $ReplicaNameShort
                    AvailabilityGroup = $object.AvailabilityGroup
                    AvailabilityMode = $object.AvailabilityMode
                    FailoverMode = $object.FailoverMode
                    ConnectionModeInPrimaryRole = $object.ConnectionModeInPrimaryRole
                    ConnectionModeInSecondaryRole = $object.ConnectionModeInSecondaryRole
                    ReadOnlyRoutingConnectionUrl = $readOnlyRoutingConnectionUrl
                    ReadOnlyRoutingList = $readOnlyRoutingList
                    SeedingMode = $object.SeedingMode
                    EnableException = $true
                    WhatIf = $module.CheckMode
                }
                $output = Set-DbaAgReplica @setReplicaParams
                $module.Result.changed = $true
            }
        }
    }
    if ($output) {
        $resultData = ConvertTo-SerializableObject -InputObject $output
        $module.Result.data = $resultData
    }
    $module.ExitJson()
}
catch {
    $module.FailJson("Configuring Availability Group replica failed: $($_.Exception.Message)", $_)
}
