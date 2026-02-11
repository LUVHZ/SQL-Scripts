-- SQL Server 2025 - Example Scripts

-- ============================================
-- 1. INTELLIGENT QUERY PROCESSING EXAMPLE
-- ============================================

-- Enable IQP features
ALTER DATABASE SCOPED CONFIGURATION SET QUERY_OPTIMIZER_HOTFIXES = ON;
ALTER DATABASE SCOPED CONFIGURATION SET PARAMETER_SENSITIVE_PLAN_OPTIMIZATION = ON;

-- Example: Adaptive Joins with Parameter Sensitivity
-- This query benefits from IQP optimization
CREATE PROCEDURE dbo.sp_GetOrdersByCustomerDynamic
    @CustomerID INT,
    @MinAmount DECIMAL(10,2) = 0
AS
BEGIN
    SELECT
        o.OrderID,
        o.OrderDate,
        o.TotalAmount,
        od.ProductID,
        od.Quantity,
        od.UnitPrice
    FROM dbo.Orders o
        INNER JOIN dbo.OrderDetails od ON o.OrderID = od.OrderID
        LEFT JOIN dbo.Customers c ON o.CustomerID = c.CustomerID
    WHERE o.CustomerID = @CustomerID
        AND o.TotalAmount >= @MinAmount
    ORDER BY o.OrderDate DESC;
END;

-- ============================================
-- 2. QUERY STORE - HINTS EXAMPLE
-- ============================================

-- View top resource-consuming queries
SELECT TOP 10
    q.query_id,
    qt.query_sql_text,
    rs.execution_count,
    rs.total_cpu_time,
    rs.total_elapsed_time,
    rs.total_logical_reads
FROM sys.query_store_query q
    INNER JOIN sys.query_store_runtime_stats rs ON q.query_id = rs.query_id
    INNER JOIN sys.query_store_query_text qt ON q.query_text_id = qt.query_text_id
ORDER BY rs.total_cpu_time DESC;

-- Apply Query Store hint to optimize a specific query
-- (Requires query_id from above)
-- EXAMPLE: EXEC sp_query_store_set_hints @query_id = 1, @query_hint_text = N'OPTION(RECOMPILE, MAXDOP 1)';

-- ============================================
-- 3. INCREMENTAL STATISTICS EXAMPLE
-- ============================================

-- Enable incremental statistics at database level
ALTER DATABASE CURRENT SET INCREMENTAL_STATISTICS ON;

-- Create partitioned table (required for incremental stats benefit)
CREATE PARTITION FUNCTION pf_OrderDate(DATETIME) AS RANGE LEFT FOR VALUES
    ('2023-01-01'), ('2024-01-01'), ('2025-01-01');

CREATE PARTITION SCHEME ps_OrderDate AS PARTITION pf_OrderDate
    TO ([PRIMARY], [PRIMARY], [PRIMARY], [PRIMARY]);

-- Apply incremental statistics
UPDATE STATISTICS dbo.Orders WITH INCREMENTAL = ON, MAXDOP = 8;

-- Verify incremental statistics are enabled
SELECT
    OBJECT_NAME(object_id) AS TableName,
    name AS StatisticName,
    incremental,
    filter_definition
FROM sys.stats
WHERE incremental = 1
ORDER BY OBJECT_NAME(object_id);

-- ============================================
-- 4. NONCLUSTERED COLUMNSTORE INDEX - EXAMPLE
-- ============================================

-- Create nonclustered columnstore for analytics without impacting OLTP
CREATE NONCLUSTERED COLUMNSTORE INDEX ncci_Orders_Analytics
ON dbo.Orders (OrderID, OrderDate, CustomerID, TotalAmount, Status)
WHERE OrderDate >= '2024-01-01';  -- Filter to recent data only

-- Verify columnstore index exists and is used
SELECT
    OBJECT_NAME(i.object_id) AS TableName,
    i.name AS IndexName,
    i.type_desc AS IndexType
FROM sys.indexes i
WHERE i.type_desc LIKE '%COLUMNSTORE%'
ORDER BY OBJECT_NAME(i.object_id);

-- ============================================
-- 5. ALWAYS ENCRYPTED - SETUP EXAMPLE
-- ============================================

-- NOTE: This requires proper key management infrastructure
-- Step 1: Create Column Master Key (CMK)
/*
CREATE COLUMN MASTER KEY MyCMK
WITH (KEY_STORE_PROVIDER_NAME = 'MSSQL_CERTIFICATE_STORE',
      KEY_PATH = 'CurrentUser/My/[thumbprint]');

-- Step 2: Create Column Encryption Key (CEK)
CREATE COLUMN ENCRYPTION KEY MyCEK
WITH VALUES (
    COLUMN_MASTER_KEY = MyCMK,
    ALGORITHM = 'RSA_OAEP',
    ENCRYPTED_VALUE = 0x...[encrypted_key_bytes]);

-- Step 3: Encrypt column during table creation
CREATE TABLE dbo.SensitiveData (
    DataID INT PRIMARY KEY,
    SSN NVARCHAR(11) ENCRYPTED WITH (ENCRYPTION_TYPE = DETERMINISTIC,
                                     ALGORITHM = 'AEAD_AES_256_CBC_HMAC_SHA_256',
                                     COLUMN_ENCRYPTION_KEY = MyCEK),
    CreditCardNumber NVARCHAR(20) ENCRYPTED WITH (ENCRYPTION_TYPE = RANDOMIZED,
                                                  ALGORITHM = 'AEAD_AES_256_CBC_HMAC_SHA_256',
                                                  COLUMN_ENCRYPTION_KEY = MyCEK)
);
*/

-- ============================================
-- 6. ROW-LEVEL SECURITY (RLS) EXAMPLE
-- ============================================

-- Create security policy function
CREATE FUNCTION dbo.SalesPersonSecurityPredicate(@SalesPersonID INT)
    RETURNS TABLE
    WITH SCHEMABINDING
AS
    RETURN (
        SELECT 1 AS AccessResult
        WHERE @SalesPersonID = CAST(SESSION_CONTEXT(N'SalesPersonID') AS INT)
           OR CAST(SESSION_CONTEXT(N'IsManager') AS BIT) = 1
    );

-- Drop if exists (for re-running)
DROP SECURITY POLICY IF EXISTS SalesSecurityPolicy;

-- Create security policy
CREATE SECURITY POLICY SalesSecurityPolicy
ADD FILTER PREDICATE dbo.SalesPersonSecurityPredicate(SalesPersonID)
ON dbo.SalesOrders
WITH (STATE = ON);

-- Test RLS by setting session context
EXEC sp_set_session_context @key = 'SalesPersonID', @value = 5;
EXEC sp_set_session_context @key = 'IsManager', @value = 0;

-- Now queries will only show orders for SalesPersonID = 5
SELECT OrderID, OrderDate, TotalAmount, SalesPersonID
FROM dbo.SalesOrders
ORDER BY OrderID;

-- Manager can see everything
EXEC sp_set_session_context @key = 'IsManager', @value = 1;
SELECT OrderID, OrderDate, TotalAmount, SalesPersonID
FROM dbo.SalesOrders
ORDER BY OrderID;

-- ============================================
-- 7. JSON ENHANCEMENTS - EXAMPLE
-- ============================================

-- Create table with JSON data
CREATE TABLE dbo.OrdersJSON (
    OrderID INT PRIMARY KEY,
    OrderData NVARCHAR(MAX) NOT NULL
);

-- Insert JSON data
INSERT INTO dbo.OrdersJSON VALUES
(1, N'{"customer":{"id":101,"name":"John","email":"john@example.com"},"items":[{"productId":1,"qty":2,"price":29.99},{"productId":2,"qty":1,"price":49.99}],"total":109.97}'),
(2, N'{"customer":{"id":102,"name":"Jane","email":"jane@example.com"},"items":[{"productId":3,"qty":3,"price":19.99}],"total":59.97}');

-- Query JSON with new SQL 2025 functions
SELECT
    OrderID,
    JSON_VALUE(OrderData, '$.customer.name') AS CustomerName,
    JSON_VALUE(OrderData, '$.customer.email') AS Email,
    JSON_VALUE(OrderData, '$.total') AS OrderTotal,
    JSON_ARRAY_LENGTH(OrderData, '$.items') AS ItemCount
FROM dbo.OrdersJSON;

-- Extract items array
SELECT
    OrderID,
    items.ProductId,
    items.Qty,
    items.Price,
    items.Qty * items.Price AS LineTotal
FROM dbo.OrdersJSON
CROSS APPLY OPENJSON(OrderData, '$.items')
    WITH (ProductId INT '$.productId', Qty INT '$.qty', Price FLOAT '$.price') AS items;

-- Build JSON response in SQL 2025 style
SELECT JSON_OBJECT(
    'OrderID', 123,
    'CustomerName', 'John Doe',
    'OrderDate', GETDATE(),
    'Items', JSON_ARRAY(456, 789, 101),
    'Total', 1000.50
) AS ResponseJSON;

-- ============================================
-- 8. GRAPH DATABASE - RELATIONSHIPS EXAMPLE
-- ============================================

-- Create node tables
CREATE TABLE dbo.Employee (
    EmployeeID INT PRIMARY KEY,
    Name NVARCHAR(100),
    Department NVARCHAR(50)
) AS NODE;

CREATE TABLE dbo.Manager (
    ManagerID INT PRIMARY KEY,
    Name NVARCHAR(100)
) AS NODE;

-- Create edge table for relationships
CREATE TABLE dbo.ReportsTo (
    CONSTRAINT Manager_Edge CONNECTION (Employee TO Manager)
) AS EDGE;

-- Insert sample data
-- INSERT INTO dbo.Employee VALUES (1, 'Alice', 'Sales'), (2, 'Bob', 'Sales');
-- INSERT INTO dbo.Manager VALUES (100, 'Charlie');
-- INSERT INTO dbo.ReportsTo VALUES ((SELECT $node_id FROM dbo.Employee WHERE EmployeeID = 1), (SELECT $node_id FROM dbo.Manager WHERE ManagerID = 100));

-- Query graph relationships
-- SELECT emp.Name AS Employee,
--        mgr.Name AS Manager
-- FROM dbo.Employee emp
--     JOIN dbo.ReportsTo ON emp.EmployeID = ReportsTo.from_id
--     JOIN dbo.Manager mgr ON mgr.ManagerID = ReportsTo.to_id;

-- ============================================
-- 9. VECTOR DATA TYPE - AI EMBEDDINGS EXAMPLE
-- ============================================

-- Create table with vector column for AI embeddings
CREATE TABLE dbo.ProductEmbeddings (
    ProductID INT PRIMARY KEY,
    ProductName NVARCHAR(255),
    Description NVARCHAR(MAX),
    -- Vector column stores AI embeddings (requires SQL Server 2025 with vector extension)
    -- Embedding VECTOR(1536)  -- Example: 1536-dimensional OpenAI embedding
);

-- Similarity search (pseudo-code for SQL 2025)
-- SELECT TOP 5
--     ProductID,
--     ProductName,
--     VECTOR_DISTANCE('cosine', @queryEmbedding, Embedding) AS SimilarityScore
-- FROM dbo.ProductEmbeddings
-- ORDER BY SimilarityScore DESC;

-- ============================================
-- 10. EXTENDED EVENTS - PERFORMANCE MONITORING
-- ============================================

-- Create event session for monitoring slow queries
CREATE EVENT SESSION [MonitorSlowQueries] ON SERVER
ADD EVENT sqlserver.sql_statement_completed(
    ACTION(sqlserver.sql_text, sqlserver.database_id, sqlserver.client_hostname)
    WHERE duration > 5000000)  -- 5 seconds in microseconds
ADD EVENT sqlserver.rpc_completed(
    WHERE duration > 5000000);

-- Add target for file storage
ALTER EVENT SESSION [MonitorSlowQueries] ON SERVER
ADD TARGET package0.event_file(SET filename = N'C:\Logs\SlowQueries');

-- Start session
ALTER EVENT SESSION [MonitorSlowQueries] ON SERVER STATE = START;

-- Query event data
-- Can be read using XQuery into sys.dm_xe_sessions

-- ============================================
-- 11. MANAGED IDENTITY FOR BACKUP EXAMPLE
-- ============================================

-- Arc-enabled SQL Server - Automated Azure backup configuration
-- EXEC msdb.managed_backup.sp_backup_config_basic
--     @enable_backup = 1,
--     @database_name = NULL,  -- All databases
--     @storage_account_url = 'https://mystorageaccount.blob.core.windows.net',
--     @storage_account_key = 'StorageAccountKey',
--     @retention_days = 30,
--     @backup_type = 'FULL';

-- Check backup configuration
-- SELECT * FROM msdb.managed_backup.sp_backup_config_info;

-- ============================================
-- 12. PARAMETER SENSITIVE PLAN HINTS
-- ============================================

-- Monitor query plans stored in Query Store
SELECT
    q.query_id,
    qt.query_sql_text,
    p.plan_id,
    CAST(p.query_plan AS XML) AS QueryPlan,
    COUNT(*) AS ExecutionCount
FROM sys.query_store_query q
    INNER JOIN sys.query_store_query_text qt ON q.query_text_id = qt.query_text_id
    INNER JOIN sys.query_store_plan p ON q.query_id = p.query_id
GROUP BY q.query_id, qt.query_sql_text, p.plan_id, p.query_plan
ORDER BY ExecutionCount DESC;

-- ============================================
-- CLEANUP
-- ============================================

-- Drop test objects (optional)
-- DROP SECURITY POLICY SalesSecurityPolicy;
-- DROP FUNCTION dbo.SalesPersonSecurityPredicate;
-- DROP TABLE dbo.OrdersJSON;
-- DROP EVENT SESSION [MonitorSlowQueries] ON SERVER;

-- ============================================
-- REFERENCES
-- ============================================
-- For more information on SQL Server 2025 features:
-- https://docs.microsoft.com/en-us/sql/sql-server/sql-server-2025-release-notes
-- https://docs.microsoft.com/en-us/sql/t-sql/statements/create-column-encryption-key-transact-sql
-- https://docs.microsoft.com/en-us/sql/relational-databases/security/row-level-security
-- https://docs.microsoft.com/en-us/sql/language-extensions/language-extensions-overview
