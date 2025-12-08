/*
    Purpose: Reusable functions and utilities for other scripts
    Usage: Create in master or utility database; reference in other scripts
    Prerequisites: CREATE FUNCTION permission
    Safety Notes: Test thoroughly; document any custom logic
    Version: SQL Server 2016+
*/

-- ============================================================================
-- 1. FORMAT_BYTES - Convert bytes to human-readable format
-- ============================================================================
CREATE OR ALTER FUNCTION dbo.format_bytes (@ByteCount BIGINT)
RETURNS NVARCHAR(50)
AS
BEGIN
    DECLARE @Result NVARCHAR(50);
    
    SELECT @Result = 
        CASE 
            WHEN @ByteCount >= 1099511627776 THEN CAST(CAST(@ByteCount AS DECIMAL(18,2)) / 1099511627776 AS NVARCHAR(20)) + ' TB'
            WHEN @ByteCount >= 1073741824 THEN CAST(CAST(@ByteCount AS DECIMAL(18,2)) / 1073741824 AS NVARCHAR(20)) + ' GB'
            WHEN @ByteCount >= 1048576 THEN CAST(CAST(@ByteCount AS DECIMAL(18,2)) / 1048576 AS NVARCHAR(20)) + ' MB'
            WHEN @ByteCount >= 1024 THEN CAST(CAST(@ByteCount AS DECIMAL(18,2)) / 1024 AS NVARCHAR(20)) + ' KB'
            ELSE CAST(@ByteCount AS NVARCHAR(20)) + ' B'
        END;
    
    RETURN @Result;
END;
GO

-- ============================================================================
-- 2. GET_TABLE_DEFINITION - Return table schema information
-- ============================================================================
CREATE OR ALTER FUNCTION dbo.get_table_definition (@TableName NVARCHAR(128))
RETURNS TABLE
AS
RETURN
(
    SELECT 
        c.name AS [ColumnName],
        t.name AS [DataType],
        c.max_length AS [MaxLength],
        c.is_nullable AS [IsNullable],
        c.is_identity AS [IsIdentity],
        ISNULL(ic.name, 'NO') AS [HasDefault]
    FROM sys.columns c
    INNER JOIN sys.types t ON c.system_type_id = t.system_type_id
    LEFT JOIN sys.default_constraints ic ON c.default_object_id = ic.object_id
    WHERE OBJECT_NAME(c.object_id) = @TableName
        AND OBJECT_ID(@TableName) IS NOT NULL
);
GO

-- ============================================================================
-- 3. CHECK_OBJECT_EXISTS - Check if table/view/procedure exists
-- ============================================================================
CREATE OR ALTER FUNCTION dbo.check_object_exists 
(
    @ObjectName NVARCHAR(128),
    @ObjectType NVARCHAR(2) = NULL  -- 'U' for table, 'V' for view, 'P' for procedure, NULL for any
)
RETURNS BIT
AS
BEGIN
    DECLARE @Exists BIT = 0;
    
    SELECT @Exists = 1
    FROM sys.objects
    WHERE name = @ObjectName
        AND (@ObjectType IS NULL OR type = @ObjectType);
    
    RETURN @Exists;
END;
GO

-- ============================================================================
-- 4. GET_ORPHANED_FILES - List orphaned database files
-- ============================================================================
CREATE OR ALTER FUNCTION dbo.get_orphaned_files ()
RETURNS TABLE
AS
RETURN
(
    SELECT 
        physical_name AS [FilePath],
        DB_NAME(database_id) AS [DatabaseName]
    FROM sys.master_files
    WHERE DB_ID(DB_NAME(database_id)) IS NULL
);
GO

-- ============================================================================
-- 5. ESTIMATE_INDEX_SIZE - Estimate index size before creation
-- ============================================================================
CREATE OR ALTER FUNCTION dbo.estimate_index_size 
(
    @TableName NVARCHAR(128),
    @IndexColumns NVARCHAR(MAX),
    @IncludeColumns NVARCHAR(MAX) = NULL
)
RETURNS TABLE
AS
RETURN
(
    SELECT 
        @TableName AS [TableName],
        @IndexColumns AS [KeyColumns],
        ISNULL(@IncludeColumns, 'None') AS [IncludedColumns],
        CAST((COUNT(*) * 8) / 1024.0 AS DECIMAL(10,2)) AS [EstimatedSizeMB]
    FROM 
        OPENROWSET(BULK 'dummy', SINGLE_CLOB) AS x(dummy)
    GROUP BY dummy
);
GO

-- ============================================================================
-- 6. GET_QUERY_PLAN - Get execution plan for stored procedure
-- ============================================================================
CREATE OR ALTER PROCEDURE dbo.get_stored_proc_info 
    @ProcName NVARCHAR(128)
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        sp.name AS [ProcedureName],
        sp.create_date,
        sp.modify_date,
        sp.execute_count = (
            SELECT execution_count 
            FROM sys.dm_exec_procedure_stats 
            WHERE object_id = sp.object_id
        ),
        COUNT(p.parameter_id) AS [ParameterCount]
    FROM sys.procedures sp
    LEFT JOIN sys.parameters p ON sp.object_id = p.object_id
    WHERE sp.name = @ProcName
    GROUP BY sp.object_id, sp.name, sp.create_date, sp.modify_date;
END;
GO

-- ============================================================================
-- Test the functions (Uncomment to test)
-- ============================================================================
/*
SELECT dbo.format_bytes(1073741824);  -- Should return "1.00 GB"
SELECT dbo.check_object_exists('your_table_name', 'U');  -- Check if table exists
SELECT * FROM dbo.get_table_definition('your_table_name');
*/
