USE [master]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE   FUNCTION [dbo].[fn_UserNameValidation] 
(@DefaultDatabase NVARCHAR(100), @UserName SYSNAME, @RoleMembership NVARCHAR(100), @Type VARCHAR(1))
RETURNS NVARCHAR(MAX)
AS
BEGIN
	DECLARE @Command NVARCHAR(MAX);
	
	IF @Type = 'M' -- Master
		SET @Command = N'USE ' + QUOTENAME(@DefaultDatabase) + ' 
IF NOT EXISTS (SELECT * FROM sys.server_principals WHERE name = N'''+ @UserName + ''') '

	IF @Type = 'R' -- RoleMembership
	   SET @Command = 
N'IF EXISTS (SELECT * FROM sys.database_principals WHERE name = ' + N'''' + @RoleMembership + '''' + ' AND type = ''R'')' + CHAR(13)
	
	IF @Type = 'O' -- Others
	   SET @Command =
N'IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = N''' + @UserName + ''') ' 


	RETURN @Command

END
GO
