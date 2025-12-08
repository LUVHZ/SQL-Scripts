/*
    Purpose: Monitor SQL Server burn rate - capacity consumption rate and resource depletion
    Usage: Track how fast resources are being consumed; identify runaway processes
    Prerequisites: VIEW SERVER STATE permission; historical data collection recommended
    Safety Notes: Read-only monitoring; use to prevent resource exhaustion
    Version: SQL Server 2008+
*/

SET NOCOUNT ON;

-- ============================================================================
-- 1. MEMORY BURN RATE
-- ============================================================================
PRINT '=== MEMORY BURN RATE ===';

SELECT 
    'Memory clerks consuming memory' AS [Metric],
    type AS [MemoryType],
    COUNT(*) AS [ClerkCount],
    CAST(SUM(pages_kb / 1024.0) AS DECIMAL(10,2)) AS [TotalMB]
FROM sys.dm_os_memory_clerks
WHERE pages_kb > 0
GROUP BY type
ORDER BY SUM(pages_kb) DESC;

-- ============================================================================
-- 2. SESSION MEMORY CONSUMPTION
-- ============================================================================
PRINT '=== SESSION MEMORY BURN (Top 10) ===';

SELECT TOP 10
    session_id,
    login_name,
    host_name,
    program_name,
    CAST((user_objects_alloc_page_count * 8.0) / 1024 AS DECIMAL(10,2)) AS [UserObjectsMB],
    CAST((internal_objects_alloc_page_count * 8.0) / 1024 AS DECIMAL(10,2)) AS [InternalObjectsMB],
    CAST(((user_objects_alloc_page_count + internal_objects_alloc_page_count) * 8.0) / 1024 AS DECIMAL(10,2)) AS [TotalMemoryMB]
FROM sys.dm_db_session_space_usage
INNER JOIN sys.dm_exec_sessions 
    ON session_id = session_id
WHERE user_objects_alloc_page_count + internal_objects_alloc_page_count > 0
ORDER BY user_objects_alloc_page_count + internal_objects_alloc_page_count DESC;

-- ============================================================================
-- 3. TRANSACTION LOG BURN RATE (Log Space Usage)
-- ============================================================================
PRINT '=== TRANSACTION LOG BURN RATE ===';

SELECT 
    db_name(tl.database_id) AS [DatabaseName],
    CAST(tl.used_log_space_in_bytes / 1024.0 / 1024.0 AS DECIMAL(10,2)) AS [UsedLogMB],
    CAST((mf.size * 8.0) / 1024 AS DECIMAL(10,2)) AS [AllocatedLogMB],
    CAST(100.0 * tl.used_log_space_in_bytes / (mf.size * 8192) AS DECIMAL(5,2)) AS [PercentUsed]
FROM sys.dm_db_log_space_usage tl
INNER JOIN sys.master_files mf 
    ON tl.database_id = mf.database_id
    AND mf.type = 1
ORDER BY CAST(100.0 * tl.used_log_space_in_bytes / (mf.size * 8192) AS DECIMAL(5,2)) DESC;

-- ============================================================================
-- 4. DISK I/O BURN RATE
-- ============================================================================
PRINT '=== DISK I/O BURN RATE ===';

SELECT 
    CAST(SUBSTRING(mf.physical_name, 0, CHARINDEX(N'\', REVERSE(mf.physical_name))) AS NVARCHAR(256)) AS [Drive],
    COUNT(*) AS [FileCount],
    CAST(SUM(divs.num_of_reads) AS BIGINT) AS [TotalReads],
    CAST(SUM(divs.num_of_writes) AS BIGINT) AS [TotalWrites],
    CAST(SUM(divs.num_of_reads + divs.num_of_writes) AS BIGINT) AS [TotalIOOperations],
    CAST((SUM(divs.num_of_reads + divs.num_of_writes) / NULLIF(DATEDIFF(HOUR, MIN(divs.sample_ms), MAX(divs.sample_ms)), 0)) AS DECIMAL(10,2)) AS [IOPerHour]
FROM sys.master_files mf
INNER JOIN sys.dm_io_virtual_file_stats(NULL, NULL) divs 
    ON mf.database_id = divs.database_id
    AND mf.file_id = divs.file_id
WHERE mf.type_desc = 'ROWS'
GROUP BY SUBSTRING(mf.physical_name, 0, CHARINDEX(N'\', REVERSE(mf.physical_name)))
ORDER BY CAST(SUM(divs.num_of_reads + divs.num_of_writes) AS BIGINT) DESC;

-- ============================================================================
-- 5. CPU BURN RATE BY SESSION
-- ============================================================================
PRINT '=== CPU BURN RATE (Top Sessions) ===';

SELECT TOP 10
    s.session_id,
    s.login_name,
    s.host_name,
    s.program_name,
    r.cpu_time AS [CPUTimeMS],
    r.total_elapsed_time AS [TotalElapsedMS],
    CAST(r.cpu_time AS FLOAT) / NULLIF(r.total_elapsed_time, 0) AS [CPUEfficiency],
    SUBSTRING(st.text, r.statement_start_offset / 2 + 1, 
        (CASE WHEN r.statement_end_offset = -1 THEN LEN(CONVERT(NVARCHAR(MAX), st.text))
            ELSE r.statement_end_offset END - r.statement_start_offset) / 2 + 1) AS [QueryText]
FROM sys.dm_exec_requests r
INNER JOIN sys.dm_exec_sessions s 
    ON r.session_id = s.session_id
OUTER APPLY sys.dm_exec_sql_text(r.sql_handle) st
WHERE r.session_id > 50
ORDER BY r.cpu_time DESC;

-- ============================================================================
-- 6. LOCK/BLOCKING BURN RATE
-- ============================================================================
PRINT '=== LOCK CONTENTION BURN RATE ===';

SELECT TOP 20
    wait_type,
    waiting_tasks_count AS [WaitCount],
    wait_time_ms AS [TotalWaitTimeMS],
    CAST(wait_time_ms / CAST(NULLIF(waiting_tasks_count, 0) AS FLOAT) AS DECIMAL(10,2)) AS [AvgWaitMS],
    signal_wait_time_ms AS [SignalWaitMS],
    CAST(100.0 * signal_wait_time_ms / wait_time_ms AS DECIMAL(5,2)) AS [SignalWaitPercent]
FROM sys.dm_exec_wait_stats
WHERE wait_type NOT IN ('SLEEP_TASK', 'WAITFOR')
ORDER BY wait_time_ms DESC;

-- ============================================================================
-- 7. QUERY PLAN CACHE BURN RATE
-- ============================================================================
PRINT '=== QUERY PLAN CACHE BURN RATE ===';

SELECT 
    'Cached Plans' AS [Metric],
    COUNT(*) AS [Count],
    CAST(SUM(CAST(cp.size_in_bytes AS BIGINT)) / 1024.0 / 1024.0 AS DECIMAL(10,2)) AS [TotalMB],
    CAST(AVG(CAST(cp.size_in_bytes AS BIGINT)) AS BIGINT) AS [AvgSizeBytes]
FROM sys.dm_exec_cached_plans cp;

-- ============================================================================
-- 8. BATCH REQUEST BURN RATE
-- ============================================================================
PRINT '=== BATCH REQUEST BURN RATE ===';

SELECT 
    'Batch Requests/sec' AS [Metric],
    CAST(cntr_value AS BIGINT) AS [Value]
FROM sys.dm_os_performance_counters
WHERE object_name = 'SQLServer:SQL Statistics'
    AND counter_name = 'Batch Requests/sec'

UNION ALL

SELECT 
    'SQL Compilations/sec',
    CAST(cntr_value AS BIGINT)
FROM sys.dm_os_performance_counters
WHERE object_name = 'SQLServer:SQL Statistics'
    AND counter_name = 'SQL Compilations/sec'

UNION ALL

SELECT 
    'SQL Re-Compilations/sec',
    CAST(cntr_value AS BIGINT)
FROM sys.dm_os_performance_counters
WHERE object_name = 'SQLServer:SQL Statistics'
    AND counter_name = 'SQL Re-Compilations/sec';

-- ============================================================================
-- 9. RUNAWAY PROCESS DETECTION
-- ============================================================================
PRINT '=== RUNAWAY PROCESS DETECTION ===';

SELECT 
    r.session_id,
    s.login_name,
    s.host_name,
    r.status,
    r.cpu_time AS [CPUTimeMS],
    r.total_elapsed_time AS [ElapsedMS],
    r.reads,
    r.writes,
    r.logical_reads,
    SUBSTRING(st.text, r.statement_start_offset / 2 + 1, 100) AS [QueryPreview]
FROM sys.dm_exec_requests r
INNER JOIN sys.dm_exec_sessions s 
    ON r.session_id = s.session_id
OUTER APPLY sys.dm_exec_sql_text(r.sql_handle) st
WHERE r.session_id > 50
    AND (r.cpu_time > 60000  -- More than 60 seconds CPU
        OR r.logical_reads > 1000000  -- More than 1M logical reads
        OR r.writes > 100000)  -- More than 100k writes
ORDER BY r.cpu_time DESC;

-- ============================================================================
-- 10. BURN RATE SUMMARY AND ALERTS
-- ============================================================================
PRINT '=== BURN RATE ALERT THRESHOLDS ===';
PRINT 'Memory: Alert if > 90% of max_server_memory';
PRINT 'Log Space: Alert if > 80% used';
PRINT 'Disk I/O: Alert if sustained > 10,000 IOPS';
PRINT 'CPU: Alert if sustained > 80%';
PRINT 'Lock Waits: Alert if > 100ms average wait';
PRINT 'Single Query CPU: Alert if > 60 seconds for active query';
PRINT 'Batch Requests: Alert if >1000 req/sec sustained';
