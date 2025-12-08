/*
    Purpose: Audit and report on user permissions and access rights
    Usage: Run to get comprehensive permission overview; export results for compliance
    Prerequisites: SELECT on system views; VIEW SERVER STATE for some queries
    Safety Notes: This is read-only; results should be reviewed regularly for security
    Version: SQL Server 2016+
*/

SET NOCOUNT ON;

-- ============================================================================
-- 1. SERVER-LEVEL PERMISSION SUMMARY
-- ============================================================================
PRINT '=== SERVER-LEVEL PERMISSIONS ===';

SELECT 
    sp.name AS [Principal],
    sp.type_desc AS [PrincipalType],
    perm.permission_name AS [Permission],
    perm.state_desc AS [PermissionState],
    'Server' AS [Scope]
FROM sys.server_principals sp
LEFT JOIN sys.server_permissions perm 
    ON sp.principal_id = perm.grantee_principal_id
WHERE sp.type IN ('S', 'U', 'G')  -- SQL login, Windows user, Windows group
ORDER BY sp.name, perm.permission_name;

-- ============================================================================
-- 2. DATABASE-LEVEL PERMISSION SUMMARY (Current Database)
-- ============================================================================
PRINT '=== DATABASE-LEVEL PERMISSIONS ===';

SELECT 
    dp.name AS [Principal],
    dp.type_desc AS [PrincipalType],
    perm.permission_name AS [Permission],
    perm.state_desc AS [PermissionState],
    perm.class_desc AS [PermissionScope],
    DB_NAME() AS [Database]
FROM sys.database_principals dp
LEFT JOIN sys.database_permissions perm 
    ON dp.principal_id = perm.grantee_principal_id
WHERE dp.type IN ('S', 'U', 'G')
ORDER BY dp.name, perm.permission_name;

-- ============================================================================
-- 3. OBJECT-LEVEL PERMISSIONS (Tables, Views, Stored Procedures)
-- ============================================================================
PRINT '=== OBJECT-LEVEL PERMISSIONS ===';

SELECT 
    dp.name AS [Principal],
    dp.type_desc AS [PrincipalType],
    perm.permission_name AS [Permission],
    perm.state_desc AS [PermissionState],
    OBJECT_NAME(perm.major_id) AS [ObjectName],
    o.type_desc AS [ObjectType],
    DB_NAME() AS [Database]
FROM sys.database_principals dp
INNER JOIN sys.database_permissions perm 
    ON dp.principal_id = perm.grantee_principal_id
INNER JOIN sys.objects o 
    ON perm.major_id = o.object_id
WHERE dp.type IN ('S', 'U', 'G')
    AND perm.class_desc = 'OBJECT_OR_COLUMN'
ORDER BY dp.name, OBJECT_NAME(perm.major_id), perm.permission_name;

-- ============================================================================
-- 4. ROLE MEMBERSHIP ANALYSIS
-- ============================================================================
PRINT '=== ROLE MEMBERSHIP ===';

SELECT 
    role.name AS [RoleName],
    member.name AS [MemberName],
    member.type_desc AS [MemberType],
    DB_NAME() AS [Database]
FROM sys.database_role_members drm
INNER JOIN sys.database_principals role 
    ON drm.role_principal_id = role.principal_id
INNER JOIN sys.database_principals member 
    ON drm.member_principal_id = member.principal_id
WHERE role.type = 'R'  -- Exclude special roles
ORDER BY role.name, member.name;

-- ============================================================================
-- 5. USERS WITH EXCESSIVE PERMISSIONS (Risk Assessment)
-- ============================================================================
PRINT '=== HIGH-RISK PERMISSIONS (Owners, db_owner, Control Server) ===';

SELECT 
    dp.name AS [Principal],
    'db_owner role member' AS [RiskType],
    DB_NAME() AS [Database],
    GETDATE() AS [AuditDate]
FROM sys.database_principals dp
INNER JOIN sys.database_role_members drm 
    ON dp.principal_id = drm.member_principal_id
INNER JOIN sys.database_principals role 
    ON drm.role_principal_id = role.principal_id
WHERE role.name = 'db_owner'
    AND dp.type IN ('S', 'U', 'G')

UNION ALL

SELECT 
    sp.name AS [Principal],
    'sysadmin role member' AS [RiskType],
    'Server' AS [Database],
    GETDATE() AS [AuditDate]
FROM sys.server_principals sp
INNER JOIN sys.server_role_members srm 
    ON sp.principal_id = srm.member_principal_id
INNER JOIN sys.server_principals role 
    ON srm.role_principal_id = role.principal_id
WHERE role.name = 'sysadmin'
    AND sp.type IN ('S', 'U', 'G')
ORDER BY [Principal];

-- ============================================================================
-- 6. DISABLED LOGINS (Should be reviewed)
-- ============================================================================
PRINT '=== DISABLED LOGINS ===';

SELECT 
    name AS [LoginName],
    type_desc AS [LoginType],
    create_date,
    modify_date,
    'DISABLED' AS [Status]
FROM sys.server_principals
WHERE is_disabled = 1
    AND type IN ('S', 'U', 'G')
ORDER BY name;
