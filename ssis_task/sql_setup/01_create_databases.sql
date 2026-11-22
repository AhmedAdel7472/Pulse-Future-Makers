/* ============================================================================
   01_create_databases.sql
   Technical Support Operations - SSIS & Data Integration Training
   Creates the two training databases. Safe to run more than once (it never drops anything).
   Run in SSMS (or sqlcmd) as a login that may create databases. Target: SQL Server 2019 or later.
   ============================================================================ */
SET NOCOUNT ON;
GO
IF DB_ID(N'TechnicalSupport_Source') IS NULL
BEGIN
    CREATE DATABASE TechnicalSupport_Source;
    PRINT 'Database TechnicalSupport_Source created.';
END
ELSE PRINT 'Database TechnicalSupport_Source already exists - nothing to do.';
GO
IF DB_ID(N'TechnicalSupport_DW') IS NULL
BEGIN
    CREATE DATABASE TechnicalSupport_DW;
    PRINT 'Database TechnicalSupport_DW created.';
END
ELSE PRINT 'Database TechnicalSupport_DW already exists - nothing to do.';
GO
SELECT name, collation_name, compatibility_level FROM sys.databases WHERE name IN (N'TechnicalSupport_Source', N'TechnicalSupport_DW');
GO
