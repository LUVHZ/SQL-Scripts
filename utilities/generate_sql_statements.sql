/*
    Purpose: Generate DDL statements for existing objects for documentation or migration
    Usage: Run to extract CREATE/ALTER statements for tables, indexes, stored procedures
    Prerequisites: VIEW DEFINITION permission on objects; SELECT on system views
    Safety Notes: Review generated statements before executing in target environment
    Version: SQL Server 2016+
*/

SET NOCOUNT ON;

-- ============================================================================
-- 1. GENERATE CREATE TABLE STATEMENTS
-- ============================================================================
PRINT '=== GENERATE TABLE CREATION SCRIPTS ===';

SELECT 
    'CREATE TABLE [dbo].[' + OBJECT_NAME(c.object_id) + '] (' + CHAR(10) +
    STRING_AGG(
        '  [' + c.name + '] ' + 
        t.name + 
        CASE 
            WHEN t.name IN ('varchar', 'nvarchar', 'char', 'nchar') 
                THEN '(' + CASE WHEN c.max_length = -1 THEN 'MAX' ELSE CAST(c.max_length AS VARCHAR(5)) END + ')'
            WHEN t.name IN ('decimal', 'numeric') 
                THEN '(' + CAST(c.precision AS VARCHAR(3)) + ',' + CAST(c.scale AS VARCHAR(3)) + ')'
            ELSE ''
        END +
        CASE WHEN c.is_nullable = 0 THEN ' NOT NULL' ELSE ' NULL' END +
        CASE WHEN c.is_identity = 1 THEN ' IDENTITY(1,1)' ELSE '' END,
        ',' + CHAR(10)
    ) + CHAR(10) +
    ');' AS [CreateTableStatement]
FROM sys.columns c
INNER JOIN sys.types t ON c.system_type_id = t.system_type_id
WHERE OBJECTPROPERTY(c.object_id, 'IsUserTable') = 1
GROUP BY c.object_id
ORDER BY OBJECT_NAME(c.object_id);

-- ============================================================================
-- 2. GENERATE CREATE INDEX STATEMENTS
-- ============================================================================
PRINT '=== GENERATE INDEX CREATION SCRIPTS ===';

SELECT 
    'CREATE ' +
    CASE WHEN i.is_unique = 1 THEN 'UNIQUE ' ELSE '' END +
    CASE WHEN i.type = 2 THEN 'NONCLUSTERED' ELSE 'CLUSTERED' END +
    ' INDEX [' + i.name + '] ON [dbo].[' + OBJECT_NAME(i.object_id) + '] (' +
    STRING_AGG(
        '[' + c.name + ']' + CASE WHEN ic.is_descending_key = 1 THEN ' DESC' ELSE ' ASC' END,
        ', '
    ) +
    ');' AS [CreateIndexStatement],
    OBJECT_NAME(i.object_id) AS [TableName],
    i.name AS [IndexName]
FROM sys.indexes i
INNER JOIN sys.index_columns ic ON i.object_id = ic.object_id AND i.index_id = ic.index_id
INNER JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
WHERE i.type <> 0  -- Exclude heaps
    AND OBJECTPROPERTY(i.object_id, 'IsUserTable') = 1
GROUP BY i.object_id, i.name, i.type, i.is_unique
ORDER BY OBJECT_NAME(i.object_id), i.name;

-- ============================================================================
-- 3. GENERATE CREATE PROCEDURE STATEMENTS
-- ============================================================================
PRINT '=== GENERATE STORED PROCEDURE SCRIPTS ===';

SELECT 
    '[ProcedureName]' = sp.name,
    '[CreateStatement]' = (
        SELECT OBJECT_DEFINITION(sp.object_id)
    )
FROM sys.procedures sp
WHERE sp.type = 'P'
ORDER BY sp.name;

-- ============================================================================
-- 4. GENERATE CREATE VIEW STATEMENTS
-- ============================================================================
PRINT '=== GENERATE VIEW SCRIPTS ===';

SELECT 
    '[ViewName]' = v.name,
    '[CreateStatement]' = (
        SELECT OBJECT_DEFINITION(v.object_id)
    )
FROM sys.views v
WHERE v.type = 'V'
ORDER BY v.name;

-- ============================================================================
-- 5. GENERATE PERMISSIONS/GRANTS
-- ============================================================================
PRINT '=== GENERATE PERMISSION SCRIPTS ===';

SELECT 
    'GRANT ' + perm.permission_name + ' ON [dbo].[' + OBJECT_NAME(perm.major_id) + '] TO [' + 
    dp.name + '];' AS [GrantStatement],
    dp.name AS [PrincipalName],
    OBJECT_NAME(perm.major_id) AS [ObjectName]
FROM sys.database_permissions perm
INNER JOIN sys.database_principals dp ON perm.grantee_principal_id = dp.principal_id
INNER JOIN sys.objects o ON perm.major_id = o.object_id
WHERE perm.state_desc = 'GRANT'
    AND o.type IN ('U', 'V', 'P')  -- Tables, Views, Procedures
ORDER BY dp.name, OBJECT_NAME(perm.major_id);

-- ============================================================================
-- 6. EXPORT ALL SCHEMAS (Alternative Method)
-- ============================================================================
PRINT '=== SCRIPT GENERATION COMPLETE ===';
PRINT 'Copy the generated statements to a new SQL file for migration or documentation';
PRINT 'Always test scripts in a development environment before deploying to production';
