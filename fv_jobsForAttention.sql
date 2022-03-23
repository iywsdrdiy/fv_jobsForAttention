USE [Monitor]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER FUNCTION [jobs].[fv_jobsForAttention] 
(	
)
RETURNS TABLE 
AS
RETURN 
(
select 'executing'	status ,* from [Monitor].[jobs].[statusExecuting]
union
select 'failed'		status ,* from [Monitor].[jobs].[statusFailed]
)
