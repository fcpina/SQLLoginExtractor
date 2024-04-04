USE [master]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE   FUNCTION [dbo].[fn_ExtractDefaultDatabase] (@Command NVARCHAR(MAX))
RETURNS NVARCHAR(MAX)
AS
BEGIN
	DECLARE @DefaultDatabase NVARCHAR(100),@DatabaseStartIndex INT, @DatabaseEndIndex INT;

	SET @DatabaseStartIndex = CHARINDEX('DEFAULT_DATABASE =', @Command) + LEN('DEFAULT_DATABASE =');
	SET @DatabaseEndIndex = CHARINDEX(', DEFAULT_LANGUAGE', @Command, @DatabaseStartIndex);
	SET @DefaultDatabase = LTRIM(RTRIM(SUBSTRING(@Command, @DatabaseStartIndex, @DatabaseEndIndex - @DatabaseStartIndex)));
	SET @DefaultDatabase = REPLACE(REPLACE(@DefaultDatabase, '[', ''), ']', '');


	RETURN @DefaultDatabase

END
GO
