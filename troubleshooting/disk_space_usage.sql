/*
    Purpose: Monitor disk space usage for data and log files to prevent out-of-space errors
    Usage: Run regularly; set up alerts when usage exceeds thresholds (e.g., 80%)
    Prerequisites: VIEW SERVER STATE permission
    Safety Notes: Read-only diagnostic; includes recommendations for expanding files
    Version: SQL Server 2016+
*/

SET NOCOUNT ON;

-- ============================================================================
-- 1. DATABASE FILE DISK USAGE (All Databases)
-- ============================================================================
PRINT '=== DATABASE FILE DISK USAGE (ALL DATABASES) ===';

SELECT 
    db_name(mf.database_id) AS [Database],
    mf.name AS [LogicalFileName],
    mf.type_desc AS [FileType],
    mf.physical_name AS [PhysicalPath],
    CAST((mf.size * 8.0) / 1024 AS DECIMAL(10,2)) AS [AllocatedMB],
    CAST((FILEPROPERTY(mf.name, 'SpaceUsed') * 8.0) / 1024 AS DECIMAL(10,2)) AS [UsedMB],
    CAST(((mf.size - FILEPROPERTY(mf.name, 'SpaceUsed')) * 8.0) / 1024 AS DECIMAL(10,2)) AS [FreeMB],
    CAST((CAST(FILEPROPERTY(mf.name, 'SpaceUsed') AS DECIMAL(10,2)) / mf.size) * 100 AS DECIMAL(5,2)) AS [PercentUsed],
    CASE 
        WHEN CAST((CAST(FILEPROPERTY(mf.name, 'SpaceUsed') AS DECIMAL(10,2)) / mf.size) * 100 AS DECIMAL(5,2)) > 90 THEN 'CRITICAL'
        WHEN CAST((CAST(FILEPROPERTY(mf.name, 'SpaceUsed') AS DECIMAL(10,2)) / mf.size) * 100 AS DECIMAL(5,2)) > 80 THEN 'HIGH'
        WHEN CAST((CAST(FILEPROPERTY(mf.name, 'SpaceUsed') AS DECIMAL(10,2)) / mf.size) * 100 AS DECIMAL(5,2)) > 60 THEN 'MEDIUM'
        ELSE 'OK'
    END AS [AlertLevel],
    mf.growth AS [AutoGrowthSize],
    CASE WHEN mf.is_percent_growth = 1 THEN 'Percent' ELSE 'MB' END AS [AutoGrowthType],
    mf.max_size,
    CASE WHEN mf.max_size = -1 THEN 'Unlimited' ELSE CAST((mf.max_size * 8.0) / 1024 AS VARCHAR(20)) + ' MB' END AS [MaxSize]
FROM sys.master_files mf
WHERE mf.database_id > 4  -- Exclude system databases
ORDER BY db_name(mf.database_id), mf.file_id;

-- ============================================================================
-- 2. SUMMARY BY DATABASE
-- ============================================================================
PRINT '=== DATABASE SPACE SUMMARY ===';

SELECT 
    db_name(mf.database_id) AS [Database],
    CAST((SUM(mf.size) * 8.0) / 1024 AS DECIMAL(10,2)) AS [TotalAllocatedMB],
    CAST((SUM(FILEPROPERTY(mf.name, 'SpaceUsed')) * 8.0) / 1024 AS DECIMAL(10,2)) AS [TotalUsedMB],
    CAST(((SUM(mf.size) - SUM(FILEPROPERTY(mf.name, 'SpaceUsed'))) * 8.0) / 1024 AS DECIMAL(10,2)) AS [TotalFreeMB],
    CAST((CAST(SUM(FILEPROPERTY(mf.name, 'SpaceUsed')) AS DECIMAL(10,2)) / SUM(mf.size)) * 100 AS DECIMAL(5,2)) AS [PercentUsed]
FROM sys.master_files mf
WHERE mf.database_id > 4
GROUP BY mf.database_id
ORDER BY [PercentUsed] DESC;

-- ============================================================================
-- 3. TRANSACTION LOG SPACE USAGE (Critical Indicator)
-- ============================================================================
PRINT '=== TRANSACTION LOG SPACE ANALYSIS ===';

SELECT 
    [Database] = db_name(tl.database_id),
    [LogSizeMB] = CAST((mf.size * 8.0) / 1024 AS DECIMAL(10,2)),
    [LogUsedMB] = CAST(tl.used_log_space_in_bytes / 1024.0 / 1024.0 AS DECIMAL(10,2)),
    [LogFreePercent] = CAST(100.0 * (1 - (CAST(tl.used_log_space_in_bytes AS DECIMAL(18,2)) / (CAST(mf.size AS DECIMAL(18,2)) * 8192))) AS DECIMAL(5,2)),
    [LogUsedPercent] = CAST((CAST(tl.used_log_space_in_bytes AS DECIMAL(18,2)) / (CAST(mf.size AS DECIMAL(18,2)) * 8192)) * 100 AS DECIMAL(5,2))
FROM sys.dm_db_log_space_usage tl
INNER JOIN sys.master_files mf 
    ON tl.database_id = mf.database_id
    AND mf.type = 1  -- Log files
ORDER BY [LogUsedPercent] DESC;

-- ============================================================================
-- 4. FILES NEAR CAPACITY
-- ============================================================================
PRINT '=== FILES AT RISK (>80% Used or At Max Size) ===';

SELECT 
    db_name(mf.database_id) AS [Database],
    mf.name AS [FileName],
    mf.type_desc AS [FileType],
    CAST((mf.size * 8.0) / 1024 AS DECIMAL(10,2)) AS [AllocatedMB],
    CAST((FILEPROPERTY(mf.name, 'SpaceUsed') * 8.0) / 1024 AS DECIMAL(10,2)) AS [UsedMB],
    CASE 
        WHEN CAST((CAST(FILEPROPERTY(mf.name, 'SpaceUsed') AS DECIMAL(10,2)) / mf.size) * 100 AS DECIMAL(5,2)) > 90 
            THEN 'CRITICAL - Expand immediately'
        WHEN mf.max_size > 0 AND mf.max_size = mf.size 
            THEN 'AT MAX SIZE - Increase max_size'
        WHEN CAST((CAST(FILEPROPERTY(mf.name, 'SpaceUsed') AS DECIMAL(10,2)) / mf.size) * 100 AS DECIMAL(5,2)) > 80 
            THEN 'HIGH - Plan expansion'
        ELSE 'OK'
    END AS [Action]
FROM sys.master_files mf
WHERE (CAST((CAST(FILEPROPERTY(mf.name, 'SpaceUsed') AS DECIMAL(10,2)) / mf.size) * 100 AS DECIMAL(5,2)) > 80
    OR (mf.max_size > 0 AND mf.max_size = mf.size))
    AND mf.database_id > 4
ORDER BY db_name(mf.database_id);

-- ============================================================================
-- 5. EXPAND FILE EXAMPLES
-- ============================================================================
PRINT '=== HOW TO EXPAND FILES ===';
PRINT 'Example - Increase data file size:';
PRINT 'ALTER DATABASE [DatabaseName] MODIFY FILE (NAME=logical_filename, SIZE=XXXXMB);';
PRINT ' ';
PRINT 'Example - Increase max size (unlimited):';
PRINT 'ALTER DATABASE [DatabaseName] MODIFY FILE (NAME=logical_filename, MAXSIZE=UNLIMITED);';
PRINT ' ';
PRINT 'Example - Change auto-growth:';
PRINT 'ALTER DATABASE [DatabaseName] MODIFY FILE (NAME=logical_filename, FILEGROWTH=256MB);';
