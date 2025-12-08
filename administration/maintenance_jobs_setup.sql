/*
    Purpose: Create and configure SQL Server maintenance jobs for regular upkeep
    Usage: Setup backup jobs, index maintenance, statistics updates scheduled execution
    Prerequisites: SQL Server Agent running; appropriate permissions; maintenance database
    Safety Notes: Schedule during low-activity windows; monitor job history regularly
    Version: SQL Server 2008+
*/

SET NOCOUNT ON;

-- ============================================================================
-- 1. CREATE MAINTENANCE PLAN JOB FRAMEWORK
-- ============================================================================
PRINT '=== MAINTENANCE JOBS SETUP ===';

/*
-- Step 1: Create Backup Job
EXEC msdb.dbo.sp_add_job
    @job_name = N'Daily_Database_Backup',
    @enabled = 1,
    @description = N'Full database backup daily at 2 AM',
    @category_name = N'[Uncategorized (Local)]';

EXEC msdb.dbo.sp_add_jobstep
    @job_name = N'Daily_Database_Backup',
    @step_name = N'Backup_Databases',
    @subsystem = N'TSQL',
    @command = N'
        DECLARE @db_name NVARCHAR(128);
        DECLARE db_cursor CURSOR FOR
        SELECT name FROM sys.databases WHERE database_id > 4 AND state = 0;
        
        OPEN db_cursor;
        FETCH NEXT FROM db_cursor INTO @db_name;
        
        WHILE @@FETCH_STATUS = 0
        BEGIN
            DECLARE @backup_path NVARCHAR(500) = ''C:\Backups\'' + @db_name + ''_'' + FORMAT(GETDATE(), ''yyyyMMdd_HHmm'') + ''.bak'';
            
            BACKUP DATABASE @db_name
            TO DISK = @backup_path
            WITH NOFORMAT, NOINIT, COMPRESSION, STATS = 10;
            
            FETCH NEXT FROM db_cursor INTO @db_name;
        END
        
        CLOSE db_cursor;
        DEALLOCATE db_cursor;
    ',
    @database_name = N'master',
    @retry_attempts = 2,
    @retry_interval = 5;

EXEC msdb.dbo.sp_add_schedule
    @schedule_name = N'Daily_2AM',
    @freq_type = 4,  -- Daily
    @freq_interval = 1,
    @active_start_time = 020000;  -- 2:00 AM

EXEC msdb.dbo.sp_attach_schedule
    @job_name = N'Daily_Database_Backup',
    @schedule_name = N'Daily_2AM';

EXEC msdb.dbo.sp_add_jobserver
    @job_name = N'Daily_Database_Backup',
    @server_name = @@SERVERNAME;
*/

-- ============================================================================
-- 2. INDEX MAINTENANCE JOB
-- ============================================================================
/*
EXEC msdb.dbo.sp_add_job
    @job_name = N'Weekly_Index_Maintenance',
    @enabled = 1,
    @description = N'Rebuild/Reorganize indexes weekly on Sunday at 3 AM';

EXEC msdb.dbo.sp_add_jobstep
    @job_name = N'Weekly_Index_Maintenance',
    @step_name = N'Rebuild_Fragmented_Indexes',
    @subsystem = N'TSQL',
    @command = N'
        DECLARE @table_name NVARCHAR(128);
        DECLARE @index_name NVARCHAR(128);
        
        DECLARE index_cursor CURSOR FOR
        SELECT OBJECT_NAME(ips.object_id), i.name
        FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, ''LIMITED'') ips
        INNER JOIN sys.indexes i ON ips.object_id = i.object_id AND ips.index_id = i.index_id
        WHERE ips.avg_fragmentation_in_percent > 30
            AND ips.page_count > 1000
            AND i.type_desc = ''NONCLUSTERED'';
        
        OPEN index_cursor;
        FETCH NEXT FROM index_cursor INTO @table_name, @index_name;
        
        WHILE @@FETCH_STATUS = 0
        BEGIN
            PRINT ''Rebuilding: '' + @table_name + ''.'' + @index_name;
            ALTER INDEX ['' + @index_name + ''] ON ['' + @table_name + ''] REBUILD;
            
            FETCH NEXT FROM index_cursor INTO @table_name, @index_name;
        END
        
        CLOSE index_cursor;
        DEALLOCATE index_cursor;
    ',
    @database_name = N'master';

EXEC msdb.dbo.sp_add_schedule
    @schedule_name = N'Weekly_Sunday_3AM',
    @freq_type = 8,  -- Weekly
    @freq_interval = 1,  -- Sunday
    @active_start_time = 030000;  -- 3:00 AM

EXEC msdb.dbo.sp_attach_schedule
    @job_name = N'Weekly_Index_Maintenance',
    @schedule_name = N'Weekly_Sunday_3AM';

EXEC msdb.dbo.sp_add_jobserver
    @job_name = N'Weekly_Index_Maintenance',
    @server_name = @@SERVERNAME;
*/

-- ============================================================================
-- 3. STATISTICS UPDATE JOB
-- ============================================================================
/*
EXEC msdb.dbo.sp_add_job
    @job_name = N'Weekly_Update_Statistics',
    @enabled = 1,
    @description = N'Update table statistics weekly on Sunday at 4 AM';

EXEC msdb.dbo.sp_add_jobstep
    @job_name = N'Weekly_Update_Statistics',
    @step_name = N'Update_All_Stats',
    @subsystem = N'TSQL',
    @command = N'EXEC sp_updatestats;',
    @database_name = N'master';

EXEC msdb.dbo.sp_add_schedule
    @schedule_name = N'Weekly_Sunday_4AM',
    @freq_type = 8,
    @freq_interval = 1,
    @active_start_time = 040000;

EXEC msdb.dbo.sp_attach_schedule
    @job_name = N'Weekly_Update_Statistics',
    @schedule_name = N'Weekly_Sunday_4AM';

EXEC msdb.dbo.sp_add_jobserver
    @job_name = N'Weekly_Update_Statistics',
    @server_name = @@SERVERNAME;
*/

-- ============================================================================
-- 4. VIEW SCHEDULED JOBS
-- ============================================================================
PRINT '=== SCHEDULED MAINTENANCE JOBS ===';

SELECT 
    j.job_id,
    j.name AS [JobName],
    j.description AS [Description],
    j.enabled AS [Enabled],
    s.name AS [ScheduleName],
    CASE s.freq_type 
        WHEN 1 THEN 'Once'
        WHEN 4 THEN 'Daily'
        WHEN 8 THEN 'Weekly'
        WHEN 16 THEN 'Monthly'
        WHEN 32 THEN 'Monthly (Relative)'
        WHEN 64 THEN 'On Startup'
        WHEN 128 THEN 'On Idle'
        ELSE 'Unknown'
    END AS [Frequency],
    s.active_start_time AS [StartTime]
FROM msdb.dbo.sysjobs j
LEFT JOIN msdb.dbo.jobschedules js 
    ON j.job_id = js.job_id
LEFT JOIN msdb.dbo.sysschedules s 
    ON js.schedule_id = s.schedule_id
WHERE j.name LIKE '%Maintenance%' OR j.name LIKE '%Backup%'
ORDER BY j.name;

-- ============================================================================
-- 5. VIEW JOB HISTORY
-- ============================================================================
PRINT '=== JOB EXECUTION HISTORY (Last 24 Hours) ===';

SELECT TOP 50
    j.name AS [JobName],
    CONVERT(VARCHAR(19), 
        CONVERT(DATETIME, 
            CONVERT(VARCHAR(8), jh.run_date) + ' ' + 
            CONVERT(VARCHAR(8), CAST(jh.run_time AS VARCHAR(6)), 112)
        ), 121) AS [ExecutedTime],
    CASE jh.run_status 
        WHEN 0 THEN 'Failed'
        WHEN 1 THEN 'Success'
        WHEN 2 THEN 'Retry'
        WHEN 3 THEN 'Cancelled'
        WHEN 4 THEN 'In Progress'
    END AS [Status],
    jh.run_duration AS [DurationSeconds],
    jh.message AS [Message]
FROM msdb.dbo.sysjobs j
INNER JOIN msdb.dbo.sysjobhistory jh 
    ON j.job_id = jh.job_id
WHERE DATEDIFF(DAY, CONVERT(DATETIME, CONVERT(VARCHAR(8), jh.run_date)), GETDATE()) <= 1
ORDER BY jh.run_date DESC, jh.run_time DESC;

-- ============================================================================
-- 6. DISABLE/ENABLE JOB
-- ============================================================================
/*
-- Disable job
EXEC msdb.dbo.sp_update_job
    @job_name = N'Daily_Database_Backup',
    @enabled = 0;

-- Enable job
EXEC msdb.dbo.sp_update_job
    @job_name = N'Daily_Database_Backup',
    @enabled = 1;
*/

-- ============================================================================
-- 7. DELETE JOB
-- ============================================================================
/*
EXEC msdb.dbo.sp_delete_job
    @job_name = N'Daily_Database_Backup',
    @delete_unused_schedule = 1;
*/

-- ============================================================================
-- 8. VIEW JOB NOTIFICATIONS
-- ============================================================================
PRINT '=== JOB NOTIFICATIONS ===';

SELECT 
    j.name AS [JobName],
    n.notify_level_eventlog AS [NotifyEventlog],
    n.notify_level_email AS [NotifyEmail],
    n.notify_level_netsend AS [NotifyNetSend],
    n.notify_level_page AS [NotifyPage],
    n.email_operator_id AS [EmailOperator],
    n.netsend_operator_id AS [NetSendOperator],
    n.page_operator_id AS [PageOperator]
FROM msdb.dbo.sysjobs j
LEFT JOIN msdb.dbo.sysnotifications n 
    ON j.job_id = n.job_id
ORDER BY j.name;

-- ============================================================================
-- 9. CONFIGURE JOB NOTIFICATION (Uncomment to use)
-- ============================================================================
/*
EXEC msdb.dbo.sp_update_job
    @job_name = N'Daily_Database_Backup',
    @notify_level_eventlog = 2,  -- On failure
    @notify_level_email = 2,
    @email_operator_name = N'SQLAdministrator';
*/

-- ============================================================================
-- 10. MAINTENANCE CHECKLIST
-- ============================================================================
PRINT '=== RECOMMENDED MAINTENANCE JOBS ===';
PRINT '1. Daily: Full database backup (2 AM)';
PRINT '2. Daily: Transaction log backup (every 15 min)';
PRINT '3. Weekly: Index rebuild/reorganize (Sunday 3 AM)';
PRINT '4. Weekly: Update statistics (Sunday 4 AM)';
PRINT '5. Monthly: DBCC CHECKDB (1st Sunday 5 AM)';
PRINT '6. Monthly: Backup cleanup (last Sunday 1 AM)';
PRINT '7. Daily: Check for blocking/deadlocks (every hour)';
