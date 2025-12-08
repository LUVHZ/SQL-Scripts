/*
    Purpose: Configure and monitor SQL Server Always On Availability Groups
    Usage: Review setup steps, modify AG names and replicas, execute sequentially
    Prerequisites: Enterprise Edition; WSFC cluster configured; mirroring endpoint created
    Safety Notes: Changes AG configuration; test in non-prod first; requires cluster failover permissions
    Version: SQL Server 2012+
*/

SET NOCOUNT ON;

-- ============================================================================
-- 1. VERIFY ALWAYS ON IS ENABLED
-- ============================================================================
PRINT '=== ALWAYS ON AVAILABILITY GROUP CONFIGURATION ===';

SELECT 
    SERVERPROPERTY('ServerName') AS [Instance],
    SERVERPROPERTY('IsHadrEnabled') AS [AlwaysOnEnabled],
    CASE WHEN SERVERPROPERTY('IsHadrEnabled') = 1 THEN 'Enabled' ELSE 'DISABLED - Enable first!' END AS [Status];

-- Enable Always On (if not already enabled):
-- ALTER SERVER CONFIGURATION SET HADR ON;

-- ============================================================================
-- 2. CREATE AVAILABILITY GROUP (Example - Uncomment and customize)
-- ============================================================================
/*
CREATE AVAILABILITY GROUP [MyAG]
WITH (
    AUTOMATED_BACKUP_PREFERENCE = SECONDARY,
    FAILURE_CONDITION_LEVEL = 3,
    HEALTH_CHECK_TIMEOUT = 30000
)
FOR DATABASE [YourDatabase]
REPLICA ON
    N'REPLICA1' WITH (
        ENDPOINT_URL = N'TCP://REPLICA1.domain.com:5022',
        AVAILABILITY_MODE = SYNCHRONOUS_COMMIT,
        FAILOVER_MODE = AUTOMATIC,
        BACKUP_PRIORITY = 100
    ),
    N'REPLICA2' WITH (
        ENDPOINT_URL = N'TCP://REPLICA2.domain.com:5022',
        AVAILABILITY_MODE = ASYNCHRONOUS_COMMIT,
        FAILOVER_MODE = MANUAL,
        BACKUP_PRIORITY = 50
    ),
    N'REPLICA3' WITH (
        ENDPOINT_URL = N'TCP://REPLICA3.domain.com:5022',
        AVAILABILITY_MODE = ASYNCHRONOUS_COMMIT,
        FAILOVER_MODE = MANUAL,
        BACKUP_PRIORITY = 25
    );
*/

-- ============================================================================
-- 3. VIEW EXISTING AVAILABILITY GROUPS
-- ============================================================================
PRINT '=== AVAILABILITY GROUPS ===';

SELECT 
    ag.name AS [AGName],
    ag.group_id,
    ag.failure_condition_level,
    ag.automated_backup_preference_desc,
    ag.health_check_timeout_in_milliseconds,
    COUNT(ar.replica_id) AS [ReplicaCount]
FROM sys.availability_groups ag
LEFT JOIN sys.availability_replicas ar 
    ON ag.group_id = ar.group_id
GROUP BY ag.name, ag.group_id, ag.failure_condition_level, 
         ag.automated_backup_preference_desc, ag.health_check_timeout_in_milliseconds
ORDER BY ag.name;

-- ============================================================================
-- 4. VIEW AVAILABILITY REPLICAS
-- ============================================================================
PRINT '=== AVAILABILITY REPLICAS ===';

SELECT 
    ag.name AS [AGName],
    ar.replica_server_name AS [ReplicaName],
    ar.endpoint_url AS [EndpointURL],
    ar.availability_mode_desc AS [AvailabilityMode],
    ar.failover_mode_desc AS [FailoverMode],
    ar.backup_priority AS [BackupPriority],
    ar.is_seed AS [IsSeeded],
    ars.role_desc AS [CurrentRole],
    ars.operational_state_desc AS [OperationalState],
    ars.connected_state_desc AS [ConnectedState]
FROM sys.availability_groups ag
INNER JOIN sys.availability_replicas ar 
    ON ag.group_id = ar.group_id
INNER JOIN sys.dm_hadr_availability_replica_states ars 
    ON ar.replica_id = ars.replica_id
ORDER BY ag.name, ar.replica_server_name;

-- ============================================================================
-- 5. VIEW AVAILABILITY GROUP DATABASES
-- ============================================================================
PRINT '=== AVAILABILITY GROUP DATABASES ===';

SELECT 
    ag.name AS [AGName],
    adb.database_name AS [DatabaseName],
    drs.database_state_desc AS [DatabaseState],
    drs.synchronization_state_desc AS [SynchronizationState],
    drs.synchronization_health_desc AS [SynchronizationHealth],
    drs.log_send_queue_size AS [LogSendQueueSize],
    drs.log_send_rate_bytes_per_second AS [LogSendRate],
    drs.redo_queue_size AS [RedoQueueSize],
    drs.redo_rate_bytes_per_second AS [RedoRate]
FROM sys.availability_groups ag
INNER JOIN sys.availability_group_listeners agl 
    ON ag.group_id = agl.group_id
INNER JOIN sys.availability_databases_cluster adb 
    ON ag.group_id = adb.group_id
LEFT JOIN sys.dm_hadr_database_replica_states drs 
    ON adb.database_name = drs.database_name
    AND ag.group_id = drs.group_id
ORDER BY ag.name, adb.database_name;

-- ============================================================================
-- 6. MONITOR SYNCHRONIZATION HEALTH
-- ============================================================================
PRINT '=== SYNCHRONIZATION HEALTH STATUS ===';

SELECT 
    ag.name AS [AGName],
    ar.replica_server_name AS [ReplicaName],
    drs.database_name AS [DatabaseName],
    drs.synchronization_state_desc AS [SyncState],
    drs.synchronization_health_desc AS [SyncHealth],
    drs.is_suspended AS [IsSuspended],
    drs.suspend_reason_desc AS [SuspendReason]
FROM sys.availability_groups ag
INNER JOIN sys.availability_replicas ar 
    ON ag.group_id = ar.group_id
INNER JOIN sys.dm_hadr_database_replica_states drs 
    ON ar.replica_id = drs.replica_id
WHERE drs.synchronization_state_desc <> 'SYNCHRONIZED'
ORDER BY ag.name, ar.replica_server_name;

-- ============================================================================
-- 7. PERFORM MANUAL FAILOVER (DANGER - Use with caution)
-- ============================================================================
PRINT '=== MANUAL FAILOVER STEPS ===';
PRINT 'To fail over to a secondary replica (run on secondary):';
PRINT 'ALTER AVAILABILITY GROUP [AGName] SET (ROLE = SECONDARY);';
PRINT ' ';
PRINT 'On the target secondary:';
PRINT 'ALTER AVAILABILITY GROUP [AGName] SET (ROLE = PRIMARY);';
PRINT ' ';
PRINT 'Note: Only synchronous replicas can be failed over without data loss';

-- ============================================================================
-- 8. CREATE AVAILABILITY GROUP LISTENER (if not exists)
-- ============================================================================
/*
ALTER AVAILABILITY GROUP [MyAG]
ADD LISTENER N'MyAG-Listener' (
    WITH IP (
        ('192.168.1.100', '255.255.255.0'),
        ('192.168.2.100', '255.255.255.0')
    ),
    PORT = 1433
);
*/

-- ============================================================================
-- 9. VIEW LISTENER CONFIGURATION
-- ============================================================================
PRINT '=== AVAILABILITY GROUP LISTENERS ===';

SELECT 
    ag.name AS [AGName],
    agl.dns_name AS [ListenerDNS],
    agl.port AS [Port],
    agl.ip_configuration_string_from_cluster AS [IPConfiguration]
FROM sys.availability_groups ag
INNER JOIN sys.availability_group_listeners agl 
    ON ag.group_id = agl.group_id
ORDER BY ag.name;

-- ============================================================================
-- 10. ADD SECONDARY REPLICA TO EXISTING AG
-- ============================================================================
/*
ALTER AVAILABILITY GROUP [MyAG]
ADD REPLICA ON 'REPLICA4'
WITH (
    ENDPOINT_URL = N'TCP://REPLICA4.domain.com:5022',
    AVAILABILITY_MODE = ASYNCHRONOUS_COMMIT,
    FAILOVER_MODE = MANUAL,
    BACKUP_PRIORITY = 10
);
*/
