/*
    Purpose: Check database integrity and health using DBCC commands
    Usage: Run regularly (weekly/monthly); investigate any errors immediately
    Prerequisites: SELECT permissions on system views; DBCC permissions
    Safety Notes: Some DBCC commands can impact performance; run during maintenance windows
    Version: SQL Server 2016+
*/

SET NOCOUNT ON;

-- ============================================================================
-- 1. DATABASE INTEGRITY CHECK (DBCC CHECKDB)
-- ============================================================================
PRINT '=== DATABASE INTEGRITY CHECK ===';
PRINT 'Starting DBCC CHECKDB at ' + CONVERT(VARCHAR(23), GETDATE(), 121);

DBCC CHECKDB (DB_NAME(), NOINDEX) WITH NO_INFOMSGS;

IF @@ERROR <> 0
BEGIN
    PRINT 'WARNING: Database integrity issues detected!';
    PRINT 'Run DBCC CHECKDB with REPAIR_ALLOW_DATA_LOSS if needed (backup first!)';
END
ELSE
    PRINT 'Database integrity check completed successfully at ' + CONVERT(VARCHAR(23), GETDATE(), 121);

-- ============================================================================
-- 2. CHECK TABLE CONSISTENCY
-- ============================================================================
PRINT '=== TABLE CONSISTENCY ===';

SELECT 
    OBJECT_NAME(i.object_id) AS [TableName],
    i.name AS [IndexName],
    ps.used_page_count,
    ps.reserved_page_count,
    CAST((ps.used_page_count * 8.0) / 1024 AS DECIMAL(10,2)) AS [UsedMB],
    CAST((ps.reserved_page_count * 8.0) / 1024 AS DECIMAL(10,2)) AS [ReservedMB]
FROM sys.indexes i
INNER JOIN sys.dm_db_partition_stats ps 
    ON i.object_id = ps.object_id
    AND i.index_id = ps.index_id
WHERE i.object_id > 100  -- Skip system tables
ORDER BY ps.used_page_count DESC;

-- ============================================================================
-- 3. CHECK FOR SUSPICIOUS PAGE ERRORS
-- ============================================================================
PRINT '=== SUSPICIOUS PAGE DETECTION ===';

SELECT 
    database_id,
    file_id,
    page_id,
    event_type,
    error_count,
    last_detected_time
FROM sys.dm_db_mirroring_auto_page_repair
WHERE database_id = DB_ID()
ORDER BY last_detected_time DESC;

IF @@ROWCOUNT = 0
    PRINT 'No suspicious pages detected.';

-- ============================================================================
-- 4. ALLOCATION CONSISTENCY CHECK
-- ============================================================================
PRINT '=== ALLOCATION CONSISTENCY ===';

DBCC CHECKALLOC (DB_NAME()) WITH NO_INFOMSGS;

IF @@ERROR <> 0
    PRINT 'WARNING: Allocation consistency issues detected!';
ELSE
    PRINT 'Allocation consistency check passed.';

-- ============================================================================
-- 5. CATALOG CONSISTENCY CHECK
-- ============================================================================
PRINT '=== CATALOG CONSISTENCY ===';

DBCC CHECKCATALOG (DB_NAME()) WITH NO_INFOMSGS;

IF @@ERROR <> 0
    PRINT 'WARNING: Catalog consistency issues detected!';
ELSE
    PRINT 'Catalog consistency check passed.';

-- ============================================================================
-- 6. DATABASE FILE INTEGRITY
-- ============================================================================
PRINT '=== DATABASE FILE STATUS ===';

SELECT 
    mf.file_id,
    mf.name,
    mf.physical_name,
    mf.type_desc,
    CAST((mf.size * 8.0) / 1024 AS DECIMAL(10,2)) AS [FileSizeMB],
    CAST((FILEPROPERTY(mf.name, 'SpaceUsed') * 8.0) / 1024 AS DECIMAL(10,2)) AS [SpaceUsedMB],
    CAST(((mf.size - FILEPROPERTY(mf.name, 'SpaceUsed')) * 8.0) / 1024 AS DECIMAL(10,2)) AS [FreeSpaceMB],
    mf.state_desc,
    mf.growth,
    mf.is_percent_growth
FROM sys.master_files mf
WHERE mf.database_id = DB_ID()
ORDER BY mf.file_id;

-- ============================================================================
-- 7. RECENT ERRORS AND WARNINGS
-- ============================================================================
PRINT '=== RECENT SQL SERVER ERRORS (Last 24 hours) ===';

DECLARE @LowerBound DATETIME = DATEADD(DAY, -1, GETDATE());

SELECT 
    er.record_id,
    er.create_date,
    er.severity,
    er.error_number,
    er.message
FROM sys.dm_server_diagnostics_log_channel_messages er
WHERE er.create_date > @LowerBound
ORDER BY er.create_date DESC;

PRINT '=== HEALTH CHECK COMPLETE ===';
PRINT 'Timestamp: ' + CONVERT(VARCHAR(23), GETDATE(), 121);
