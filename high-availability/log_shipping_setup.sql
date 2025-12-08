/*
    Purpose: Configure and monitor SQL Server Log Shipping for disaster recovery
    Usage: Setup primary and secondary databases, monitor synchronization status
    Prerequisites: Full backup of primary database; network access between servers
    Safety Notes: Requires careful setup; test restore on secondary before production
    Version: SQL Server 2005+
*/

SET NOCOUNT ON;

-- ============================================================================
-- 1. SETUP LOG SHIPPING (Primary Database)
-- ============================================================================
PRINT '=== LOG SHIPPING CONFIGURATION ===';

-- Enable backup job (run on primary)
/*
USE [msdb];
GO

-- Create backup job
EXEC sp_add_log_shipping_primary_database
    @database = N'YourDatabase',
    @backup_directory = N'C:\LogShipping\Backup\',
    @backup_share = N'\\LogShippingServer\LogShipping\Backup\',
    @backup_job_name = N'LogShipping_YourDatabase_Backup',
    @backup_retention_period = 4320,  -- 3 days in minutes
    @backup_compression = 1,
    @backup_frequency = 15,  -- Every 15 minutes
    @p_storage_redundancy = 1;
GO
*/

-- ============================================================================
-- 2. ADD SECONDARY DATABASE TO LOG SHIPPING
-- ============================================================================
/*
EXEC sp_add_log_shipping_secondary_database
    @secondary_database = N'YourDatabase',
    @primary_server = N'PrimaryServer',
    @primary_database = N'YourDatabase',
    @restore_delay = 0,
    @restore_mode = 0,  -- Standby mode (read-only)
    @disconnect_users = 0,
    @block_size = 512,
    @buffer_count = 70,
    @max_transfer_size = 1048576,
    @restore_job_name = N'LogShipping_YourDatabase_Restore',
    @copy_job_name = N'LogShipping_YourDatabase_Copy';
GO
*/

-- ============================================================================
-- 3. VIEW LOG SHIPPING CONFIGURATION
-- ============================================================================
PRINT '=== LOG SHIPPING PRIMARIES ===';

SELECT 
    primary_id,
    primary_server AS [PrimaryServer],
    primary_database AS [PrimaryDatabase],
    backup_directory AS [BackupDirectory],
    backup_share AS [BackupShare],
    backup_retention_period AS [RetentionMinutes],
    backup_frequency_interval AS [FrequencyMinutes],
    backup_compression_option AS [CompressionEnabled],
    last_backup_file AS [LastBackupFile],
    last_backup_date AS [LastBackupTime]
FROM msdb.dbo.log_shipping_primary_databases
ORDER BY primary_database;

-- ============================================================================
-- 4. VIEW SECONDARY LOG SHIPPING DATABASES
-- ============================================================================
PRINT '=== LOG SHIPPING SECONDARIES ===';

SELECT 
    secondary_id,
    secondary_server AS [SecondaryServer],
    secondary_database AS [SecondaryDatabase],
    primary_server AS [PrimaryServer],
    primary_database AS [PrimaryDatabase],
    restore_delay AS [RestoreDelayMinutes],
    restore_mode AS [RestoreMode],
    disconnect_users AS [DisconnectUsers],
    last_restored_file AS [LastRestoredFile],
    last_restored_date AS [LastRestoredTime]
FROM msdb.dbo.log_shipping_secondary_databases
ORDER BY secondary_database;

-- ============================================================================
-- 5. MONITOR LOG SHIPPING STATUS
-- ============================================================================
PRINT '=== LOG SHIPPING STATUS ===';

SELECT 
    lpm.secondary_server AS [SecondaryServer],
    lpm.secondary_database AS [SecondaryDatabase],
    lpm.restore_threshold_in_minutes AS [RestoreThresholdMinutes],
    lpm.last_restored_file AS [LastRestoredFile],
    lpm.last_restored_date AS [LastRestoredTime],
    lpm.last_restore_latency_in_minutes AS [LatencyMinutes],
    DATEDIFF(MINUTE, lpm.last_restored_date, GETDATE()) AS [MinutesSinceRestore],
    CASE 
        WHEN DATEDIFF(MINUTE, lpm.last_restored_date, GETDATE()) > lpm.restore_threshold_in_minutes
            THEN 'ALERT - Restore threshold exceeded'
        ELSE 'OK'
    END AS [Status]
FROM msdb.dbo.log_shipping_monitor_secondary lpm
ORDER BY lpm.secondary_database;

-- ============================================================================
-- 6. VIEW BACKUP JOB HISTORY
-- ============================================================================
PRINT '=== LOG SHIPPING BACKUP JOB STATUS ===';

SELECT TOP 10
    j.name AS [JobName],
    jh.run_date,
    jh.run_time,
    CASE jh.run_status 
        WHEN 0 THEN 'Failed'
        WHEN 1 THEN 'Success'
        WHEN 2 THEN 'Retry'
        WHEN 3 THEN 'Cancelled'
        WHEN 4 THEN 'In Progress'
    END AS [Status],
    jh.message
FROM msdb.dbo.sysjobs j
INNER JOIN msdb.dbo.sysjobhistory jh 
    ON j.job_id = jh.job_id
WHERE j.name LIKE 'LogShipping_%Backup%'
ORDER BY jh.run_date DESC, jh.run_time DESC;

-- ============================================================================
-- 7. VIEW RESTORE JOB HISTORY
-- ============================================================================
PRINT '=== LOG SHIPPING RESTORE JOB STATUS ===';

SELECT TOP 10
    j.name AS [JobName],
    jh.run_date,
    jh.run_time,
    CASE jh.run_status 
        WHEN 0 THEN 'Failed'
        WHEN 1 THEN 'Success'
        WHEN 2 THEN 'Retry'
        WHEN 3 THEN 'Cancelled'
        WHEN 4 THEN 'In Progress'
    END AS [Status],
    jh.message
FROM msdb.dbo.sysjobs j
INNER JOIN msdb.dbo.sysjobhistory jh 
    ON j.job_id = jh.job_id
WHERE j.name LIKE 'LogShipping_%Restore%'
ORDER BY jh.run_date DESC, jh.run_time DESC;

-- ============================================================================
-- 8. FAILOVER TO SECONDARY (Uncomment when ready)
-- ============================================================================
/*
-- On primary, disable log shipping
EXEC sp_delete_log_shipping_primary_secondary
    @primary_database = N'YourDatabase',
    @secondary_server = N'SecondaryServer',
    @secondary_database = N'YourDatabase';

EXEC sp_delete_log_shipping_primary_database
    @database = N'YourDatabase';

-- On secondary, remove log shipping config
EXEC sp_delete_log_shipping_secondary_database
    @secondary_database = N'YourDatabase';

-- Restore with recovery
RESTORE DATABASE [YourDatabase] WITH RECOVERY;
*/

-- ============================================================================
-- 9. TROUBLESHOOTING
-- ============================================================================
PRINT '=== TROUBLESHOOTING CHECKS ===';
PRINT '1. Verify backup share is accessible from both servers';
PRINT '2. Check SQL Agent is running on both servers';
PRINT '3. Verify LogShipping jobs are enabled and scheduled';
PRINT '4. Check job history for errors in backup and restore jobs';
PRINT '5. Verify network connectivity between servers';
