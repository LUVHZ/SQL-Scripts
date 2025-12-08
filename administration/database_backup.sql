/*
    Purpose: Create full and differential database backups with verification
    Usage: Modify @DatabaseName and @BackupPath, then execute scheduled backup
    Prerequisites: sysadmin role; backup path must exist and be accessible
    Safety Notes: Verify backup location has sufficient space; test restore regularly
    Version: SQL Server 2016+
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @DatabaseName NVARCHAR(128) = 'YourDatabaseName';
DECLARE @BackupPath NVARCHAR(500) = 'C:\Backups\';
DECLARE @Timestamp NVARCHAR(20) = FORMAT(GETDATE(), 'yyyyMMdd_HHmmss');
DECLARE @FullBackupFile NVARCHAR(500);
DECLARE @DiffBackupFile NVARCHAR(500);
DECLARE @ErrorMessage NVARCHAR(MAX);

BEGIN TRY
    -- Verify database exists
    IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = @DatabaseName)
    BEGIN
        RAISERROR('Database %s does not exist', 16, 1, @DatabaseName);
    END

    -- ========================================================================
    -- FULL DATABASE BACKUP
    -- ========================================================================
    SET @FullBackupFile = @BackupPath + @DatabaseName + '_FULL_' + @Timestamp + '.bak';
    
    PRINT '[' + CONVERT(VARCHAR(23), GETDATE(), 121) + '] Starting FULL backup...';
    
    BACKUP DATABASE @DatabaseName
    TO DISK = @FullBackupFile
    WITH 
        NOFORMAT,           -- Append to media
        NOINIT,             -- Don't overwrite
        NAME = @DatabaseName + ' Full Backup ' + @Timestamp,
        SKIP,               -- Skip expiration check
        STATS = 10,         -- Progress messages every 10%
        COMPRESSION;        -- Use backup compression (SQL 2008 R2+)
    
    PRINT '[' + CONVERT(VARCHAR(23), GETDATE(), 121) + '] Full backup completed: ' + @FullBackupFile;

    -- ========================================================================
    -- VERIFY FULL BACKUP
    -- ========================================================================
    PRINT '[' + CONVERT(VARCHAR(23), GETDATE(), 121) + '] Verifying backup integrity...';
    
    RESTORE VERIFYONLY FROM DISK = @FullBackupFile;
    
    PRINT '[' + CONVERT(VARCHAR(23), GETDATE(), 121) + '] Backup verification successful';

    -- ========================================================================
    -- DIFFERENTIAL BACKUP (optional - uncomment if needed)
    -- ========================================================================
    /*
    SET @DiffBackupFile = @BackupPath + @DatabaseName + '_DIFF_' + @Timestamp + '.bak';
    
    PRINT '[' + CONVERT(VARCHAR(23), GETDATE(), 121) + '] Starting DIFFERENTIAL backup...';
    
    BACKUP DATABASE @DatabaseName
    TO DISK = @DiffBackupFile
    WITH 
        DIFFERENTIAL,
        NOFORMAT,
        NOINIT,
        NAME = @DatabaseName + ' Differential Backup ' + @Timestamp,
        SKIP,
        STATS = 10,
        COMPRESSION;
    
    PRINT '[' + CONVERT(VARCHAR(23), GETDATE(), 121) + '] Differential backup completed: ' + @DiffBackupFile;
    */

    -- ========================================================================
    -- BACKUP FILE INFORMATION
    -- ========================================================================
    SELECT 
        @DatabaseName AS [Database],
        @FullBackupFile AS [BackupFile],
        CAST(CAST(FILEPROPERTY(@FullBackupFile, 'Access') AS INT) / 1024.0 / 1024.0 AS DECIMAL(10,2)) AS [SizeMB],
        CONVERT(VARCHAR(23), GETDATE(), 121) AS [CompletedTime];

END TRY
BEGIN CATCH
    SET @ErrorMessage = ERROR_MESSAGE();
    PRINT '[ERROR] ' + @ErrorMessage;
    RAISERROR(@ErrorMessage, 16, 1);
END CATCH
