/*
    Purpose: Monitor tempdb usage and identify growth issues
    Usage: Run when tempdb usage is high or when experiencing tempdb errors
    Prerequisites: VIEW SERVER STATE permission
    Safety Notes: Read-only diagnostic; identify root causes before increasing tempdb size
    Version: SQL Server 2016+
*/

SET NOCOUNT ON;

-- ============================================================================
-- 1. TEMPDB FILE SIZE AND USAGE
-- ============================================================================
PRINT '=== TEMPDB FILE INFORMATION ===';

SELECT 
    mf.file_id,
    mf.name,
    mf.physical_name,
    mf.type_desc,
    CAST((mf.size * 8.0) / 1024 AS DECIMAL(10,2)) AS [AllocatedMB],
    CAST((FILEPROPERTY(mf.name, 'SpaceUsed') * 8.0) / 1024 AS DECIMAL(10,2)) AS [UsedMB],
    CAST(((mf.size - FILEPROPERTY(mf.name, 'SpaceUsed')) * 8.0) / 1024 AS DECIMAL(10,2)) AS [FreeMB],
    CAST((CAST(FILEPROPERTY(mf.name, 'SpaceUsed') AS DECIMAL(10,2)) / mf.size) * 100 AS DECIMAL(5,2)) AS [PercentUsed],
    mf.growth AS [GrowthSize],
    CASE WHEN mf.is_percent_growth = 1 THEN 'Percent' ELSE 'MB' END AS [GrowthType]
FROM sys.master_files mf
WHERE mf.database_id = DB_ID('tempdb')
ORDER BY mf.file_id;

-- ============================================================================
-- 2. TEMPDB OBJECT USAGE (What's consuming space?)
-- ============================================================================
PRINT '=== TEMPDB OBJECT SPACE USAGE ===';

SELECT TOP 20
    OBJECT_NAME(ps.object_id) AS [ObjectName],
    ps.index_id,
    ps.partition_number,
    CAST((ps.used_page_count * 8.0) / 1024 AS DECIMAL(10,2)) AS [UsedMB],
    CAST((ps.reserved_page_count * 8.0) / 1024 AS DECIMAL(10,2)) AS [ReservedMB],
    ps.row_count
FROM tempdb.sys.dm_db_partition_stats ps
WHERE OBJECT_NAME(ps.object_id) NOT LIKE '%sys%'  -- Exclude system objects
ORDER BY ps.used_page_count DESC;

-- ============================================================================
-- 3. IDENTIFY SESSIONS USING TEMPDB
-- ============================================================================
PRINT '=== SESSIONS USING TEMPDB ===';

SELECT 
    es.session_id,
    es.login_name,
    es.host_name,
    es.program_name,
    CAST((su.user_objects_alloc_page_count * 8.0) / 1024 AS DECIMAL(10,2)) AS [UserObjectsMB],
    CAST((su.internal_objects_alloc_page_count * 8.0) / 1024 AS DECIMAL(10,2)) AS [InternalObjectsMB],
    CAST(((su.user_objects_alloc_page_count + su.internal_objects_alloc_page_count) * 8.0) / 1024 AS DECIMAL(10,2)) AS [TotalMB],
    CONVERT(VARCHAR(23), es.login_time, 121) AS [LoginTime]
FROM sys.dm_db_session_space_usage su
INNER JOIN sys.dm_exec_sessions es 
    ON su.session_id = es.session_id
WHERE (su.user_objects_alloc_page_count + su.internal_objects_alloc_page_count) > 0
ORDER BY TotalMB DESC;

-- ============================================================================
-- 4. TEMPDB TASK SPACE USAGE (Per-task allocation)
-- ============================================================================
PRINT '=== TEMPDB TASK (T-SQL Command) ALLOCATION ===';

SELECT TOP 10
    task_space_usage_id,
    session_id,
    request_id,
    CAST((user_objects_alloc_page_count * 8.0) / 1024 AS DECIMAL(10,2)) AS [UserObjectsMB],
    CAST((internal_objects_alloc_page_count * 8.0) / 1024 AS DECIMAL(10,2)) AS [InternalObjectsMB]
FROM sys.dm_db_task_space_usage
ORDER BY (user_objects_alloc_page_count + internal_objects_alloc_page_count) DESC;

-- ============================================================================
-- 5. TEMPDB GROWTH HISTORY
-- ============================================================================
PRINT '=== TEMPDB CURRENT CONFIGURATION ===';

SELECT 
    'MAX SIZE BEFORE GROWTH' = 
        CAST((SUM(mf.size) * 8.0) / 1024 AS DECIMAL(10,2)) + ' MB',
    'CURRENT USED SPACE' = 
        CAST((SUM(FILEPROPERTY(mf.name, 'SpaceUsed')) * 8.0) / 1024 AS DECIMAL(10,2)) + ' MB',
    'FREE SPACE' = 
        CAST(((SUM(mf.size) - SUM(FILEPROPERTY(mf.name, 'SpaceUsed'))) * 8.0) / 1024 AS DECIMAL(10,2)) + ' MB'
FROM sys.master_files mf
WHERE mf.database_id = DB_ID('tempdb');

-- ============================================================================
-- 6. RECOMMENDATIONS
-- ============================================================================
PRINT '=== TROUBLESHOOTING RECOMMENDATIONS ===';
PRINT '1. If tempdb is growing rapidly:';
PRINT '   - Check for unbounded result sets or large temp tables';
PRINT '   - Look for missing indexes causing hash joins';
PRINT '   - Review sessions using tempdb (Query 3 above)';
PRINT ' ';
PRINT '2. To expand tempdb:';
PRINT '   - ALTER DATABASE tempdb MODIFY FILE (NAME=tempdev, SIZE=XXXXMB);';
PRINT '   - Should be multiple files (one per CPU core) on separate drives';
PRINT ' ';
PRINT '3. To reduce tempdb growth:';
PRINT '   - Clear application temp table usage';
PRINT '   - Optimize queries with large intermediate result sets';
PRINT '   - Use table variables instead of temp tables when possible';
