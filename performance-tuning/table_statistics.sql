/*
    Purpose: Update table statistics to enable query optimizer to make better decisions
    Usage: Run after major data loads or when statistics are stale
    Prerequisites: ALTER ANY STATISTICS permission; SELECT on tables
    Safety Notes: Can temporarily increase I/O; coordinate with backup windows
    Version: SQL Server 2016+
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

-- ============================================================================
-- 1. CHECK STATISTICS STALENESS
-- ============================================================================
PRINT '=== STALE STATISTICS ANALYSIS ===';

SELECT 
    OBJECT_NAME(s.object_id) AS [TableName],
    s.name AS [StatisticName],
    sp.last_updated,
    sp.rows,
    sp.rows_sampled,
    CAST(CAST(sp.rows_sampled AS DECIMAL(18,2)) / sp.rows * 100 AS DECIMAL(5,2)) AS [SamplingPercent],
    DATEDIFF(DAY, sp.last_updated, GETDATE()) AS [DaysSinceUpdate]
FROM sys.stats s
CROSS APPLY sys.dm_db_stats_properties(s.object_id, s.stats_id) sp
WHERE OBJECTPROPERTY(s.object_id, 'IsUserTable') = 1
ORDER BY sp.last_updated ASC;

-- ============================================================================
-- 2. UPDATE ALL STATISTICS WITH FULL SCAN
-- ============================================================================
PRINT '=== UPDATING ALL STATISTICS (FULL SCAN) ===';

DECLARE @StatisticUpdate NVARCHAR(MAX) = '';
DECLARE @TableName NVARCHAR(128);
DECLARE @StatisticName NVARCHAR(128);

DECLARE stats_cursor CURSOR FOR
SELECT 
    OBJECT_NAME(s.object_id),
    s.name
FROM sys.stats s
WHERE OBJECTPROPERTY(s.object_id, 'IsUserTable') = 1
    AND s.stats_id > 0;  -- Skip auto-created stats initially

OPEN stats_cursor;

FETCH NEXT FROM stats_cursor INTO @TableName, @StatisticName;

WHILE @@FETCH_STATUS = 0
BEGIN
    BEGIN TRY
        PRINT 'Updating: ' + @TableName + '.' + @StatisticName;
        UPDATE STATISTICS [' + @TableName + '] ([' + @StatisticName + ']) WITH FULLSCAN;
        PRINT 'Success: ' + @TableName + '.' + @StatisticName;
    END TRY
    BEGIN CATCH
        PRINT 'Warning: ' + @TableName + '.' + @StatisticName + ' - ' + ERROR_MESSAGE();
    END CATCH
    
    FETCH NEXT FROM stats_cursor INTO @TableName, @StatisticName;
END

CLOSE stats_cursor;
DEALLOCATE stats_cursor;

-- ============================================================================
-- 3. UPDATE STATISTICS WITH DEFAULT SAMPLING (Faster alternative)
-- ============================================================================
-- Uncomment to run default sampling instead of FULLSCAN
/*
PRINT '=== UPDATING ALL STATISTICS (DEFAULT SAMPLING) ===';

EXEC sp_updatestats;
*/

-- ============================================================================
-- 4. VERIFY AUTO UPDATE STATISTICS IS ENABLED
-- ============================================================================
PRINT '=== AUTO UPDATE STATISTICS STATUS ===';

SELECT 
    name AS [DatabaseName],
    is_auto_update_stats_on AS [AutoUpdateStatsEnabled],
    is_auto_update_stats_async_on AS [AutoUpdateStatsAsync]
FROM sys.databases
WHERE name = DB_NAME();

-- Enable if needed (uncomment):
-- ALTER DATABASE [YourDatabaseName] SET AUTO_UPDATE_STATISTICS ON;
-- ALTER DATABASE [YourDatabaseName] SET AUTO_UPDATE_STATISTICS_ASYNC ON;

-- ============================================================================
-- 5. POST-UPDATE STATISTICS SUMMARY
-- ============================================================================
PRINT '=== STATISTICS UPDATED ===';

SELECT 
    OBJECT_NAME(s.object_id) AS [TableName],
    COUNT(*) AS [StatisticCount],
    MAX(sp.last_updated) AS [MostRecentUpdate]
FROM sys.stats s
CROSS APPLY sys.dm_db_stats_properties(s.object_id, s.stats_id) sp
WHERE OBJECTPROPERTY(s.object_id, 'IsUserTable') = 1
GROUP BY s.object_id
ORDER BY MAX(sp.last_updated) DESC;
