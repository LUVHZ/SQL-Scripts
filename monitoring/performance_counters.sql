/*
    Purpose: Monitor SQL Server performance counters and system metrics
    Usage: Run regularly to track performance; establish baselines; identify trends
    Prerequisites: VIEW SERVER STATE permission; PerfMon data available
    Safety Notes: Read-only diagnostic; use for trend analysis and capacity planning
    Version: SQL Server 2008+
*/

SET NOCOUNT ON;

-- ============================================================================
-- 1. MONITOR CPU USAGE
-- ============================================================================
PRINT '=== CPU USAGE MONITORING ===';

SELECT 
    'CPU Usage' AS [Metric],
    CAST(100.0 * SUM(signal_wait_time_ms) / SUM(wait_time_ms) AS DECIMAL(5,2)) AS [SignalWaitPercent],
    CAST(100.0 * SUM(wait_time_ms - signal_wait_time_ms) / SUM(wait_time_ms) AS DECIMAL(5,2)) AS [ResourceWaitPercent]
FROM sys.dm_exec_requests;

-- ============================================================================
-- 2. MONITOR MEMORY USAGE
-- ============================================================================
PRINT '=== MEMORY USAGE ===';

SELECT 
    'Physical Memory Available (MB)' AS [Metric],
    CAST(physical_memory_in_bytes / 1024.0 / 1024.0 AS DECIMAL(10,2)) AS [Value],
    'System' AS [Source]
FROM sys.dm_os_sys_info

UNION ALL

SELECT 
    'SQL Server Memory (MB)',
    CAST(pages_kb / 1024.0 AS DECIMAL(10,2)),
    'Buffer Pool'
FROM sys.dm_os_memory_clerks
WHERE type = 'MEMOBJ_PROCESS'

UNION ALL

SELECT 
    'Target Memory (MB)',
    CAST(target_server_memory_kb / 1024.0 AS DECIMAL(10,2)),
    'Configured'
FROM sys.dm_os_memory_nodes;

-- ============================================================================
-- 3. MONITOR I/O PERFORMANCE
-- ============================================================================
PRINT '=== DISK I/O PERFORMANCE ===';

SELECT TOP 10
    CAST(SUBSTRING(mf.physical_name, 0, CHARINDEX(N'\', REVERSE(mf.physical_name))) AS NVARCHAR(256)) AS [Drive],
    'Data File' AS [FileType],
    COUNT(*) AS [FileCount],
    CAST(SUM(divs.num_of_reads) AS BIGINT) AS [TotalReads],
    CAST(SUM(divs.num_of_writes) AS BIGINT) AS [TotalWrites],
    CAST(SUM(divs.io_stall_read_ms) AS BIGINT) AS [ReadStallMS],
    CAST(SUM(divs.io_stall_write_ms) AS BIGINT) AS [WriteStallMS]
FROM sys.master_files mf
INNER JOIN sys.dm_io_virtual_file_stats(NULL, NULL) divs 
    ON mf.database_id = divs.database_id
    AND mf.file_id = divs.file_id
WHERE mf.type_desc = 'ROWS'
GROUP BY SUBSTRING(mf.physical_name, 0, CHARINDEX(N'\', REVERSE(mf.physical_name)))
ORDER BY SUM(divs.io_stall_read_ms) + SUM(divs.io_stall_write_ms) DESC;

-- ============================================================================
-- 4. MONITOR NETWORK I/O
-- ============================================================================
PRINT '=== NETWORK I/O PERFORMANCE ===';

SELECT 
    'Total Logins' AS [Metric],
    CAST(cntr_value AS BIGINT) AS [Value]
FROM sys.dm_os_performance_counters
WHERE object_name = 'SQLServer:General Statistics'
    AND counter_name = 'Logins/sec'

UNION ALL

SELECT 
    'Connections',
    CAST(cntr_value AS BIGINT)
FROM sys.dm_os_performance_counters
WHERE object_name = 'SQLServer:General Statistics'
    AND counter_name = 'User Connections'

UNION ALL

SELECT 
    'Batch Requests/sec',
    CAST(cntr_value AS BIGINT)
FROM sys.dm_os_performance_counters
WHERE object_name = 'SQLServer:SQL Statistics'
    AND counter_name = 'Batch Requests/sec';

-- ============================================================================
-- 5. MONITOR LOCK WAITS
-- ============================================================================
PRINT '=== LOCK WAIT TIMES ===';

SELECT TOP 10
    wait_type,
    waiting_tasks_count AS [WaitCount],
    wait_time_ms AS [TotalWaitTimeMS],
    CAST(wait_time_ms / CAST(NULLIF(waiting_tasks_count, 0) AS FLOAT) AS DECIMAL(10,2)) AS [AvgWaitTimeMS],
    max_wait_time_ms AS [MaxWaitTimeMS],
    signal_wait_time_ms AS [SignalWaitTimeMS]
FROM sys.dm_exec_wait_stats
WHERE wait_type NOT IN (
    'CLR_SEMAPHORE', 'CLR_AUTO_EVENT', 'CLR_MANUAL_EVENT',
    'SLEEP_TASK', 'WAITFOR'
)
ORDER BY wait_time_ms DESC;

-- ============================================================================
-- 6. MONITOR COMPILATIONS AND RECOMPILATIONS
-- ============================================================================
PRINT '=== COMPILATION STATISTICS ===';

SELECT 
    'SQL Compilations/sec' AS [Metric],
    CAST(cntr_value AS BIGINT) AS [Value]
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
-- 7. MONITOR CACHE HIT RATIO
-- ============================================================================
PRINT '=== BUFFER POOL HIT RATIO ===';

SELECT 
    'Buffer Cache Hit Ratio' AS [Metric],
    CAST(100.0 * SUM(CASE WHEN mrows.cntr_type = 1 THEN mrows.cntr_value ELSE 0 END) / 
        SUM(CASE WHEN mrows.cntr_type = 2 THEN mrows.cntr_value ELSE 0 END) AS DECIMAL(5,2)) AS [HitRatio%]
FROM sys.dm_os_performance_counters mrows
WHERE mrows.object_name = 'SQLServer:Buffer Manager'
    AND mrows.counter_name IN ('Buffer cache hit ratio', 'Buffer cache hit ratio base');

-- ============================================================================
-- 8. MONITOR PAGE READS/WRITES
-- ============================================================================
PRINT '=== PAGE READS/WRITES ===';

SELECT 
    'Page Reads/sec' AS [Metric],
    CAST(cntr_value AS BIGINT) AS [Value]
FROM sys.dm_os_performance_counters
WHERE object_name = 'SQLServer:Buffer Manager'
    AND counter_name = 'Page reads/sec'

UNION ALL

SELECT 
    'Page Writes/sec',
    CAST(cntr_value AS BIGINT)
FROM sys.dm_os_performance_counters
WHERE object_name = 'SQLServer:Buffer Manager'
    AND counter_name = 'Page writes/sec';

-- ============================================================================
-- 9. MONITOR TRANSACTION LOG ACTIVITY
-- ============================================================================
PRINT '=== TRANSACTION LOG ACTIVITY ===';

SELECT 
    'Log Flushes/sec' AS [Metric],
    CAST(cntr_value AS BIGINT) AS [Value]
FROM sys.dm_os_performance_counters
WHERE object_name = 'SQLServer:Transactions'
    AND counter_name = 'Log Flushes/sec'

UNION ALL

SELECT 
    'Transactions/sec',
    CAST(cntr_value AS BIGINT)
FROM sys.dm_os_performance_counters
WHERE object_name = 'SQLServer:Transactions'
    AND counter_name = 'Transactions/sec';

-- ============================================================================
-- 10. PERFORMANCE COUNTER BASELINE
-- ============================================================================
PRINT '=== ESTABLISH PERFORMANCE BASELINE ===';
PRINT 'Recommended Baselines to Monitor:';
PRINT '- CPU Usage: Track signal waits vs resource waits';
PRINT '- Memory: Monitor % Available bytes (should be > 25%)';
PRINT '- Disk I/O: Monitor read/write stalls per second';
PRINT '- Cache Hit Ratio: Buffer cache should be > 99%';
PRINT '- Lock Waits: Monitor top wait types for blocking';
PRINT '- Compilations: High recompiles indicate plan cache issues';
