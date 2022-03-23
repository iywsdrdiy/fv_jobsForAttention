USE [Monitor]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
create  function [jobs].[fv_xp_sqlagent_enum_jobs] ()
returns table
-- The extended, undocumented, stored procedure "master.dbo.xp_sqlagent_enum_jobs" is best handled downstream as a view or table.
-- You will need a loopback linked server, and the permission to use this and openquery.
as
return (
	select * 
	from openquery(loopback, 'set fmtonly off; exec master.dbo.xp_sqlagent_enum_jobs 1, '''' with result sets 
						(
							(
								Job_ID uniqueidentifier,
								Last_Run_Date int,
								Last_Run_Time int,
								Next_Run_Date int,
								Next_Run_Time int,
								Next_Run_Schedule_ID int,
								Requested_To_Run int,
								Request_Source int,
								Request_Source_ID varchar(100),
								Running int,
								Current_Step int,
								Current_Retry_Attempt int, 
								State int
							)
						)
				')
)
;
GO
