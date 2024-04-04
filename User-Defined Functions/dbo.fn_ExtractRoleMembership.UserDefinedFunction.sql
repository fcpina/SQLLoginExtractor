USE [master]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE   FUNCTION [dbo].[fn_ExtractRoleMembership] (@Command NVARCHAR(MAX))
RETURNS NVARCHAR(MAX)
AS
BEGIN
	DECLARE @FirstQuotePosition INT, @SecondQuotePosition INT, @RoleMembership NVARCHAR(100);

	SET @FirstQuotePosition  = CHARINDEX('''', @Command);
	SET @SecondQuotePosition = CHARINDEX('''', @Command, @FirstQuotePosition + 1);
	SET @RoleMembership      = SUBSTRING(@Command, @FirstQuotePosition + 1, @SecondQuotePosition - @FirstQuotePosition - 1);


	RETURN @RoleMembership

END
GO
