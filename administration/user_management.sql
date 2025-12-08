/*
    Purpose: Create and manage SQL Server logins and database users with proper permissions
    Usage: Review and execute portions based on your needs (login creation, user mapping, etc.)
    Prerequisites: sysadmin role; review security requirements before executing
    Safety Notes: This script performs user/permission changes; test in non-prod first
    Version: SQL Server 2016+
*/

-- ============================================================================
-- 1. CREATE A NEW LOGIN (SQL Authentication)
-- ============================================================================
-- Uncomment and modify as needed
/*
CREATE LOGIN [newuser] 
    WITH PASSWORD = 'ComplexPassword123!@#'
    , DEFAULT_DATABASE = [master]
    , CHECK_POLICY = ON
    , CHECK_EXPIRATION = ON;
*/

-- ============================================================================
-- 2. CREATE A DATABASE USER FROM LOGIN
-- ============================================================================
-- Uncomment and modify as needed
/*
USE [YourDatabaseName];
GO

CREATE USER [newuser] FOR LOGIN [newuser];
*/

-- ============================================================================
-- 3. GRANT COMMON PERMISSION SETS
-- ============================================================================
-- Read-only user
/*
USE [YourDatabaseName];
GO

CREATE ROLE [db_readonly] AUTHORIZATION [dbo];

GRANT SELECT ON SCHEMA::dbo TO [db_readonly];
CREATE USER [readonly_user] FOR LOGIN [readonly_user];
ALTER ROLE [db_readonly] ADD MEMBER [readonly_user];
*/

-- ============================================================================
-- 4. AUDIT EXISTING USERS AND PERMISSIONS
-- ============================================================================
-- View all logins on server
SELECT 
    name AS [LoginName],
    type_desc AS [LoginType],
    is_disabled,
    create_date,
    modify_date
FROM sys.server_principals
WHERE type IN ('S', 'U', 'G')  -- SQL, Windows User, Windows Group
ORDER BY create_date DESC;

-- View database users for current database
SELECT 
    dp.name AS [UserName],
    dp.type_desc AS [UserType],
    dp.create_date,
    ssp.name AS [LinkedLogin]
FROM sys.database_principals dp
LEFT JOIN sys.server_principals ssp 
    ON dp.sid = ssp.sid
WHERE dp.type IN ('S', 'U', 'G')
ORDER BY dp.create_date DESC;

-- View role memberships in current database
SELECT 
    role.name AS [RoleName],
    member.name AS [MemberName],
    member.type_desc AS [MemberType]
FROM sys.database_role_members drm
INNER JOIN sys.database_principals role 
    ON drm.role_principal_id = role.principal_id
INNER JOIN sys.database_principals member 
    ON drm.member_principal_id = member.principal_id
ORDER BY role.name, member.name;

-- ============================================================================
-- 5. DISABLE/ENABLE LOGIN
-- ============================================================================
-- Disable (commented out)
/*
ALTER LOGIN [username] DISABLE;
*/

-- Enable (commented out)
/*
ALTER LOGIN [username] ENABLE;
*/

-- ============================================================================
-- 6. DROP USER/LOGIN (DANGER - Use with caution)
-- ============================================================================
-- First drop database user, then login
-- DROP USER [username];  -- In target database
-- DROP LOGIN [username];  -- At server level
