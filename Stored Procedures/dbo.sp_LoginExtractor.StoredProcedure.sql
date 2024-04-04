USE [master]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- EXECUTE dbo.sp_LoginExtractor 'username'
CREATE     PROCEDURE [dbo].[sp_LoginExtractor]
	@UserName SYSNAME
AS
BEGIN
	SET NOCOUNT ON;

	CREATE TABLE #UserName (UserName SYSNAME)
	CREATE TABLE #UserPassword (UserPasswordCommand NVARCHAR(MAX))
	CREATE TABLE #UserPermissions (Id INT IDENTITY(1,1) PRIMARY KEY,DatabaseName NVARCHAR(100)
	,PermissionLevel NVARCHAR(100),PermissionCommand NVARCHAR(MAX))

	--Get user login information
	INSERT INTO #UserPassword (UserPasswordCommand)
	EXECUTE [dbo].[sp_help_revlogin] @UserName

	INSERT INTO #UserName SELECT @UserName

	--Extracting permissions 
	EXEC sp_MSforeachdb '
	BEGIN
		USE [?];
		DECLARE @UserName NVARCHAR(MAX) = (SELECT UserName FROM #UserName);
		--Role Memberships
		INSERT INTO #UserPermissions
		SELECT ''?'', ''RoleMemberships'', ''EXEC sp_addrolemember @rolename = ''
		+ SPACE(1) + QUOTENAME(USER_NAME(rm.role_principal_id), '''''') + '''', @membername = '''' + SPACE(1) + QUOTENAME(@UserName, '''''')
		FROM    sys.database_role_members AS rm
		WHERE   USER_NAME(rm.member_principal_id) = @UserName
		ORDER BY rm.role_principal_id ASC
	END'

	EXEC sp_MSforeachdb '
	BEGIN
		USE [?];
		DECLARE @UserName NVARCHAR(MAX) = (SELECT UserName FROM #UserName);
		--Object Level Permissions
		INSERT INTO #UserPermissions
		SELECT ''?'', ''ObjectLevel'', CASE WHEN perm.state <> ''W'' THEN perm.state_desc ELSE ''GRANT'' END
		+ SPACE(1) + perm.permission_name + SPACE(1) + ''ON '' + QUOTENAME(SCHEMA_NAME(obj.schema_id)) + ''.'' + QUOTENAME(obj.name)
		+ CASE WHEN cl.column_id IS NULL THEN SPACE(0) ELSE ''('' + QUOTENAME(cl.name) + '')'' END
		+ SPACE(1) + ''TO'' + SPACE(1) + QUOTENAME(@UserName) COLLATE database_default
		+ CASE WHEN perm.state <> ''W'' THEN SPACE(0) ELSE SPACE(1) + ''WITH GRANT OPTION'' END 
		FROM    sys.database_permissions AS perm
		INNER JOIN sys.objects AS obj		      ON perm.major_id = obj.[object_id]
		INNER JOIN sys.database_principals AS usr ON perm.grantee_principal_id = usr.principal_id
		LEFT JOIN  sys.columns AS cl              ON cl.column_id = perm.minor_id AND cl.[object_id] = perm.major_id
		WHERE usr.name = @UserName
		ORDER BY obj.name ASC
	END'

	EXEC sp_MSforeachdb '
	BEGIN
		USE [?];
		DECLARE @UserName NVARCHAR(MAX) = (SELECT UserName FROM #UserName);
		--Database Level Permissions
		INSERT INTO #UserPermissions
		SELECT ''?'', ''DatabaseLevel'', CASE WHEN perm.state <> ''W'' THEN perm.state_desc ELSE ''GRANT'' END
		+ SPACE(1) + perm.permission_name + SPACE(1)
		+ SPACE(1) + ''TO'' + SPACE(1) + QUOTENAME(@UserName) COLLATE database_default
		+ CASE WHEN perm.state <> ''W'' THEN SPACE(0) ELSE SPACE(1) + ''WITH GRANT OPTION'' END
		FROM sys.server_permissions AS perm
		INNER JOIN sys.server_principals AS usr ON perm.grantee_principal_id = usr.principal_id
		WHERE usr.name = @UserName
		ORDER BY perm.permission_name ASC, perm.state_desc ASC
	END'


	DECLARE @UserLoginCommand VARCHAR (MAX), @DefaultDatabase NVARCHAR(100), @SQL NVARCHAR(MAX);

	SELECT @UserLoginCommand = UserPasswordCommand FROM #UserPassword
	IF ISNULL(@UserLoginCommand, '') = ''
	BEGIN
	   RAISERROR ('No login information found for user %s. Please verify the username is correct and try again.', 16, 1, @UserName) WITH NOWAIT
	   RETURN
	END

	--Extract the default database
	SET @DefaultDatabase = (SELECT dbo.fn_ExtractDefaultDatabase(@UserLoginCommand))

	--Start building the permission script
	SET @SQL = (SELECT dbo.fn_UserNameValidation ('master', @UserName, NULL, 'M')) + CHAR(13) 
	SET @SQL += N'BEGIN ' + CHAR(13)
	SET @SQL += @UserLoginCommand + CHAR(13) + CHAR(13)

	--Building master database permissions
	DECLARE @MasterUserCommand NVARCHAR(MAX), @MasterId INT;
	SELECT TOP 1 @MasterId = Id, @MasterUserCommand = PermissionCommand  
	FROM #UserPermissions 
	WHERE DatabaseName = 'master' 
	ORDER BY Id ASC

	WHILE @@ROWCOUNT > 0 AND @MasterId IS NOT NULL
	BEGIN
		SET @SQL += @MasterUserCommand + CHAR(13) 

		DELETE FROM #UserPermissions WHERE @MasterId = Id
		SELECT TOP 1 @MasterId = Id, @MasterUserCommand = PermissionCommand 
		FROM #UserPermissions 
		WHERE DatabaseName = 'master' 
		ORDER BY Id ASC
	END
	--Finished building master database permissions

	--Building default database permissions
	SET @SQL +=  CHAR(13) + 'USE ' + QUOTENAME(@DefaultDatabase) + CHAR(13)
	SET @SQL += (SELECT dbo.fn_UserNameValidation (@DefaultDatabase, @UserName, NULL, 'O')) + CHAR(13)
	SET @SQL += 'CREATE USER [' + @UserName + '] FOR LOGIN [' + @UserName + '] WITH DEFAULT_SCHEMA = [' + SCHEMA_NAME() + ']' 
	+ CHAR(13) + CHAR(13)

	DECLARE @DefaultDatabaseId INT, @DefaultDBPermissionLevel VARCHAR(100)
	,@DefaultDBPermissionCommand NVARCHAR(MAX), @DefaultDBRoleMembership NVARCHAR(100)
	
	SELECT TOP 1 @DefaultDatabaseId = Id,@DefaultDBPermissionLevel = PermissionLevel
	,@DefaultDBPermissionCommand = PermissionCommand 
	FROM #UserPermissions
	WHERE DatabaseName = @DefaultDatabase
	ORDER BY Id ASC

	WHILE @@ROWCOUNT > 0 AND @DefaultDatabaseId IS NOT NULL
	BEGIN
		IF @DefaultDBPermissionLevel = 'RoleMemberships'
		BEGIN
			SET @DefaultDBRoleMembership = (SELECT dbo.fn_ExtractRoleMembership(@DefaultDBPermissionCommand))
			SET @SQL += (SELECT dbo.fn_UserNameValidation (NULL, NULL, @DefaultDBRoleMembership, 'R'))
			SET @SQL += @DefaultDBPermissionCommand + ', @membername = N''' + @UserName + '''' + CHAR(13) + CHAR(13)
		END

		IF @DefaultDBPermissionLevel = 'ObjectLevel'
		   SET @SQL += @DefaultDBPermissionCommand + CHAR(13)

		DELETE FROM #UserPermissions WHERE Id = @DefaultDatabaseId 

		SELECT TOP 1 @DefaultDatabaseId = Id,@DefaultDBPermissionLevel = PermissionLevel
		,@DefaultDBPermissionCommand = PermissionCommand 
		FROM #UserPermissions 
		WHERE DatabaseName = @DefaultDatabase
		ORDER BY Id ASC
	END
	--Finished building default database permissions

	--Building other databases permissions
	DECLARE @Id INT, @PermissionLevel VARCHAR(100),@PermissionCommand NVARCHAR(MAX)
	,@RoleMembership NVARCHAR(100),@DatabaseName NVARCHAR(100),@LastUsedDatabase NVARCHAR(100);

	SELECT TOP 1 @Id = Id, @PermissionLevel = PermissionLevel, @PermissionCommand = PermissionCommand
	,@DatabaseName = DatabaseName
	FROM #UserPermissions
	WHERE PermissionLevel IN('ObjectLevel', 'RoleMemberships')
	ORDER BY Id ASC

	SET @LastUsedDatabase = ''
	WHILE @@ROWCOUNT > 0 AND @Id IS NOT NULL
	BEGIN
		IF @LastUsedDatabase <> @DatabaseName
		BEGIN
			SET @LastUsedDatabase = @DatabaseName
			SET @SQL += CHAR(13) + 'USE ' + QUOTENAME(@LastUsedDatabase) + CHAR(13)
			SET @SQL += (SELECT dbo.fn_UserNameValidation (@LastUsedDatabase, @UserName, NULL, 'O')) + CHAR(13)
			SET @SQL += 'CREATE USER [' + @UserName + '] FOR LOGIN [' + @UserName + '] WITH DEFAULT_SCHEMA = [' + SCHEMA_NAME() + ']' 
			+ CHAR(13) + CHAR(13)
		END

		IF @PermissionLevel = 'RoleMemberships'
		BEGIN
			SET @RoleMembership = (SELECT dbo.fn_ExtractRoleMembership(@PermissionCommand))
			SET @SQL += (SELECT dbo.fn_UserNameValidation (NULL, NULL, @RoleMembership, 'R'))
			SET @SQL += @PermissionCommand + ', @membername = N'''+ @UserName + '''' + CHAR(13) + CHAR(13)
		END

		IF @PermissionLevel = 'ObjectLevel'
		   SET @SQL += @PermissionCommand + CHAR(13)

		DELETE FROM #UserPermissions WHERE Id = @Id 

		SELECT TOP 1 @Id = Id, @PermissionLevel = PermissionLevel, @PermissionCommand = PermissionCommand
		,@DatabaseName = DatabaseName
		FROM #UserPermissions
		WHERE PermissionLevel IN('ObjectLevel', 'RoleMemberships')
		ORDER BY Id ASC
	END
    --Finished building other databases permissions

	SET @SQL += CHAR(13) + 'ALTER LOGIN ' +QUOTENAME(@UserName) + ' ENABLE' + CHAR(13)
	SET @SQL += CHAR(13) + 'END'
	
	EXECUTE dbo.LongPrint @string = @SQL
END
GO
