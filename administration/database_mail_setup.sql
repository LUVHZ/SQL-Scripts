/*
    Purpose: Configure SQL Server Database Mail for sending alerts and notifications
    Usage: Setup mail profile, test email delivery, configure notifications
    Prerequisites: TCP/IP enabled; SMTP server accessible; proper permissions
    Safety Notes: Credentials stored in SQL Server; use encryption for sensitive emails
    Version: SQL Server 2008+
*/

SET NOCOUNT ON;

-- ============================================================================
-- 1. ENABLE DATABASE MAIL
-- ============================================================================
PRINT '=== DATABASE MAIL CONFIGURATION ===';

/*
-- Enable Database Mail (run once)
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;

EXEC sp_configure 'Database Mail XPs', 1;
RECONFIGURE;

-- Create mail account
EXEC msdb.dbo.sysmail_add_account_sp
    @account_name = 'SQLServerAlerts',
    @description = 'SQL Server alert account',
    @email_address = 'sqlserver-alerts@company.com',
    @display_name = 'SQL Server Alerts',
    @mailserver_name = 'smtp.company.com',
    @mailserver_type = 'SMTP',
    @port = 587,
    @username = 'smtpuser@company.com',
    @password = 'EmailPassword123!',
    @use_default_credentials = 0,
    @enable_ssl = 1;

-- Create mail profile
EXEC msdb.dbo.sysmail_add_profile_sp
    @profile_name = 'SQLServerProfile',
    @description = 'Profile for SQL Server alerts';

-- Add account to profile
EXEC msdb.dbo.sysmail_add_profileaccount_sp
    @profile_name = 'SQLServerProfile',
    @account_name = 'SQLServerAlerts',
    @sequence_number = 1;

-- Grant access to msdb role
EXEC msdb.dbo.sysmail_add_principalprofile_sp
    @principal_name = 'public',
    @profile_name = 'SQLServerProfile',
    @is_default = 1;
*/

-- ============================================================================
-- 2. VIEW MAIL ACCOUNTS
-- ============================================================================
PRINT '=== MAIL ACCOUNTS ===';

SELECT 
    account_id,
    name AS [AccountName],
    description AS [Description],
    email_address AS [EmailAddress],
    display_name AS [DisplayName],
    replyto_address AS [ReplyToAddress],
    mailserver_name AS [SMTPServer],
    mailserver_type AS [MailServerType],
    port AS [Port],
    username AS [Username],
    use_default_credentials AS [UseDefaultCredentials],
    enable_ssl AS [EnableSSL]
FROM msdb.dbo.sysmail_account
ORDER BY name;

-- ============================================================================
-- 3. VIEW MAIL PROFILES
-- ============================================================================
PRINT '=== MAIL PROFILES ===';

SELECT 
    profile_id,
    name AS [ProfileName],
    description AS [Description]
FROM msdb.dbo.sysmail_profile
ORDER BY name;

-- ============================================================================
-- 4. VIEW PROFILE ACCOUNTS
-- ============================================================================
PRINT '=== PROFILE ACCOUNTS ===';

SELECT 
    p.name AS [ProfileName],
    a.name AS [AccountName],
    pa.sequence_number AS [SequenceNumber]
FROM msdb.dbo.sysmail_profile p
INNER JOIN msdb.dbo.sysmail_profileaccount pa 
    ON p.profile_id = pa.profile_id
INNER JOIN msdb.dbo.sysmail_account a 
    ON pa.account_id = a.account_id
ORDER BY p.name, pa.sequence_number;

-- ============================================================================
-- 5. TEST MAIL DELIVERY
-- ============================================================================
PRINT '=== TEST EMAIL DELIVERY ===';

/*
EXEC msdb.dbo.sp_send_dbmail
    @profile_name = 'SQLServerProfile',
    @recipients = 'admin@company.com',
    @subject = 'Test Email from SQL Server',
    @body = 'This is a test message from SQL Server Database Mail.',
    @importance = 'Normal';

-- Check status
EXEC msdb.dbo.sysmail_help_status_sp;
*/

-- ============================================================================
-- 6. VIEW MAIL QUEUE
-- ============================================================================
PRINT '=== MAIL QUEUE STATUS ===';

SELECT 
    mail_id,
    profile_id,
    subject,
    recipients,
    copy_recipients,
    blind_copy_recipients,
    body,
    body_format,
    importance,
    sensitivity,
    sent_status,
    sent_date,
    last_mod_date,
    created_date
FROM msdb.dbo.sysmail_mailitems
ORDER BY created_date DESC;

-- ============================================================================
-- 7. VIEW SENT MAIL LOG
-- ============================================================================
PRINT '=== SENT MAIL LOG ===';

SELECT TOP 100
    log_id,
    event_type AS [EventType],
    log_date AS [LogDate],
    description AS [Description]
FROM msdb.dbo.sysmail_log
ORDER BY log_date DESC;

-- ============================================================================
-- 8. CONFIGURE SQL AGENT NOTIFICATION
-- ============================================================================
/*
-- Set SQL Agent to use Database Mail profile
USE msdb;
GO

EXEC sp_configure 'Agent XPs', 1;
RECONFIGURE;

-- Enable SQL Agent notification
EXEC msdb.dbo.sp_set_sqlagent_properties
    @email_profile = 'SQLServerProfile',
    @netsend_address = NULL,
    @pager_address = NULL,
    @pager_days_begin = 'Monday',
    @pager_days_end = 'Friday',
    @pager_step_begin = '09:00',
    @pager_step_end = '18:00',
    @cpu_poller_enabled = 0,
    @alert_replace_runtime_tokens = 1,
    @oem_source_id = 0,
    @local_host_server = @@SERVERNAME;
*/

-- ============================================================================
-- 9. SEND ALERT EMAIL
-- ============================================================================
/*
-- Example: Send email on job failure
EXEC msdb.dbo.sp_send_dbmail
    @profile_name = 'SQLServerProfile',
    @recipients = 'dba@company.com',
    @subject = 'SQL Job Failed',
    @body = 'Job [JobName] failed at ' + CONVERT(VARCHAR(23), GETDATE(), 121),
    @importance = 'High';
*/

-- ============================================================================
-- 10. TROUBLESHOOTING DATABASE MAIL
-- ============================================================================
PRINT '=== DATABASE MAIL TROUBLESHOOTING ===';
PRINT 'Common Issues:';
PRINT '1. SMTP server connection failed - Verify server name, port, and firewall';
PRINT '2. Authentication failed - Check username and password';
PRINT '3. Email not sent - Check mail queue status';
PRINT '4. SSL errors - Verify SSL certificate is valid';
PRINT '5. Test with telnet: telnet smtp.company.com 587';
PRINT ' ';
PRINT 'Useful Procedures:';
PRINT 'sp_send_dbmail - Send email';
PRINT 'sysmail_help_status_sp - Check mail status';
PRINT 'sysmail_help_configure_sp - View configuration';
