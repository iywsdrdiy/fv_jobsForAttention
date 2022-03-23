USE [Monitor]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO






create   view [jobs].[statusExecuting] as

/*
declare @string varchar(max); set @string = '/ISSERVER "\"\SSISDB\SSIS\Integration Services Project\EE_BASE_DAILY.dtsx\"" /SERVER bwp10824001 /X86 /ENVREFERENCE 1 /Par "\"$ServerOption::LOGGING_LEVEL(Int16)\"";1 /Par "\"$ServerOption::SYNCHRONIZED(Boolean)\"";True /CALLERINFO SQLAGENT /REPORTING E';
select reverse(substring(@string,1,charindex('\""',@string,1)-1));
select charindex('\',reverse(substring(@string,1,charindex('\""',@string,1)-1)),1);
select lower(reverse(substring(reverse(substring(@string,1,charindex('\""',@string,1)-1)),1,charindex('\',reverse(substring(@string,1,charindex('\""',@string,1)-1)),1)-1)));
*/


with runningJobSteps as (
	select * from monitor.dbo.fv_xp_sqlagent_enum_jobs() where state != 4 --'Idle'
)
,sysJobActivity as (
--only want the latest session
	select	ja.*
	from		msdb.dbo.sysjobactivity		ja
	inner join	msdb.dbo.syssessions		s1	on s1.session_id = ja.session_id and s1.agent_start_date = (select max(agent_start_date) from msdb.dbo.syssessions)
)

SELECT

	 j.name									[jobName]
	,case j.description when 'No description available.' then '' else j.description end [description]
	,sjs.step_id							[stepId]
	,sjs.step_name							[stepName]
	,coalesce(lower(sjs.subsystem),'')		[subsystem]
	,coalesce(lower(sjs.database_name),'')	[database]
	,case lower(sjs.subsystem) when 'ssis' then 
		reverse(substring(reverse(substring(coalesce(sjs.command,''),1,charindex('\""',coalesce(sjs.command,''),1)-1)),1,charindex('\',reverse(substring(coalesce(sjs.command,''),1,charindex('\""',coalesce(sjs.command,''),1)-1)),1)-1))
		--don't know if I really need "coalesce(sjs.command,'')" in here or can get away with plain "sjs.command"
		else coalesce(sjs.command,'') end																			[command]
	,'[requestSourceID]: ' + rjs.Request_Source_id	[message]
    ,a.start_execution_date																							[jobStartDate]
	,trim('|' from trim ('0:' from 
	 right('0' + convert(varchar,(datediff(ss,a.start_execution_date,getdate())/86400)%24),2)+':'+
	 right('0' + convert(varchar,(datediff(ss,a.start_execution_date,getdate())/3600)%60),2)+':'+
	 right('0' + convert(varchar,(datediff(ss,a.start_execution_date,getdate())/60)%60),2)+':'+
	 right('0' + convert(varchar,datediff(ss,a.start_execution_date,getdate())%60),2) + '|'))								[jobElapsedTime]
	,DATEDIFF(SECOND, a.start_execution_date, GETDATE())															[jobElapsedSeconds]
	,coalesce(dateadd(second,
				cast(substring(RIGHT(REPLICATE('0', 8) + CAST(sjh.run_duration as varchar(8)), 8), 1,2) as bigint)*86400 +
				cast(substring(RIGHT(REPLICATE('0', 8) + CAST(sjh.run_duration as varchar(8)), 8), 3,2) as bigint)*3600 +
				cast(substring(RIGHT(REPLICATE('0', 8) + CAST(sjh.run_duration as varchar(8)), 8), 5,2) as bigint)*60 +
				cast(substring(RIGHT(REPLICATE('0', 8) + CAST(sjh.run_duration as varchar(8)), 8), 7,2) as bigint)*1 
				, last_executed_step_date),	a.start_execution_date	)												[stepStartDate]
	,trim('|' from trim ('0:' from
		coalesce(
	 right('0' + convert(varchar,(datediff(second
		,dateadd(second,
				cast(substring(RIGHT(REPLICATE('0', 8) + CAST(sjh.run_duration as varchar(8)), 8), 1,2) as bigint)*86400 +
				cast(substring(RIGHT(REPLICATE('0', 8) + CAST(sjh.run_duration as varchar(8)), 8), 3,2) as bigint)*3600 +
				cast(substring(RIGHT(REPLICATE('0', 8) + CAST(sjh.run_duration as varchar(8)), 8), 5,2) as bigint)*60 +
				cast(substring(RIGHT(REPLICATE('0', 8) + CAST(sjh.run_duration as varchar(8)), 8), 7,2) as bigint)*1 
				, last_executed_step_date)
			,getdate())/86400)%24),2)+':'+
	 right('0' + convert(varchar,(datediff(second
		,dateadd(second,
				cast(substring(RIGHT(REPLICATE('0', 8) + CAST(sjh.run_duration as varchar(8)), 8), 1,2) as bigint)*86400 +
				cast(substring(RIGHT(REPLICATE('0', 8) + CAST(sjh.run_duration as varchar(8)), 8), 3,2) as bigint)*3600 +
				cast(substring(RIGHT(REPLICATE('0', 8) + CAST(sjh.run_duration as varchar(8)), 8), 5,2) as bigint)*60 +
				cast(substring(RIGHT(REPLICATE('0', 8) + CAST(sjh.run_duration as varchar(8)), 8), 7,2) as bigint)*1 
				, last_executed_step_date)
			,getdate())/3600)%60),2)+':'+
	 right('0' + convert(varchar,(datediff(second
		,dateadd(second,
				cast(substring(RIGHT(REPLICATE('0', 8) + CAST(sjh.run_duration as varchar(8)), 8), 1,2) as bigint)*86400 +
				cast(substring(RIGHT(REPLICATE('0', 8) + CAST(sjh.run_duration as varchar(8)), 8), 3,2) as bigint)*3600 +
				cast(substring(RIGHT(REPLICATE('0', 8) + CAST(sjh.run_duration as varchar(8)), 8), 5,2) as bigint)*60 +
				cast(substring(RIGHT(REPLICATE('0', 8) + CAST(sjh.run_duration as varchar(8)), 8), 7,2) as bigint)*1 
				, last_executed_step_date)
			,getdate())/60)%60),2)+':'+
	 right('0' + convert(varchar,datediff(second
		,dateadd(second,
				cast(substring(RIGHT(REPLICATE('0', 8) + CAST(sjh.run_duration as varchar(8)), 8), 1,2) as bigint)*86400 +
				cast(substring(RIGHT(REPLICATE('0', 8) + CAST(sjh.run_duration as varchar(8)), 8), 3,2) as bigint)*3600 +
				cast(substring(RIGHT(REPLICATE('0', 8) + CAST(sjh.run_duration as varchar(8)), 8), 5,2) as bigint)*60 +
				cast(substring(RIGHT(REPLICATE('0', 8) + CAST(sjh.run_duration as varchar(8)), 8), 7,2) as bigint)*1 
				, last_executed_step_date)
			,getdate())%60),2)
	, 
		 right('0' + convert(varchar,(datediff(ss,a.start_execution_date,getdate())/86400)%24),2)+':'+
		 right('0' + convert(varchar,(datediff(ss,a.start_execution_date,getdate())/3600)%60),2)+':'+
		 right('0' + convert(varchar,(datediff(ss,a.start_execution_date,getdate())/60)%60),2)+':'+
		 right('0' + convert(varchar,datediff(ss,a.start_execution_date,getdate())%60),2)
		) + '|' ))																											[stepElapsedTime]
	,coalesce(datediff(second
		,dateadd(second,
				cast(substring(RIGHT(REPLICATE('0', 8) + CAST(sjh.run_duration as varchar(8)), 8), 1,2) as bigint)*86400 +
				cast(substring(RIGHT(REPLICATE('0', 8) + CAST(sjh.run_duration as varchar(8)), 8), 3,2) as bigint)*3600 +
				cast(substring(RIGHT(REPLICATE('0', 8) + CAST(sjh.run_duration as varchar(8)), 8), 5,2) as bigint)*60 +
				cast(substring(RIGHT(REPLICATE('0', 8) + CAST(sjh.run_duration as varchar(8)), 8), 7,2) as bigint)*1 
				, last_executed_step_date)
			,getdate())
	,
		DATEDIFF(SECOND, a.start_execution_date, GETDATE()))														[stepElapsedSeconds]
	,j.job_id
	--,msdb.dbo.agent_datetime(a.start_execution_date) [start_execution_date]

from		msdb.dbo.sysjobs			j --msdb.dbo.sysjobs_view shows only *my* jobs, apparently
inner join	sysjobactivity				a	on j.job_id = a.job_id
inner join	runningjobsteps				rjs	on j.job_id = rjs.job_id
inner join	msdb.dbo.sysjobsteps		sjs	on (j.job_id = sjs.job_id and rjs.current_step = sjs.step_id )
left join	msdb.dbo.sysjobhistory		sjh	on	a.job_id =	sjh.job_id
											and a.last_executed_step_id = sjh.step_id
											and a.last_executed_step_date = convert(datetime,(STUFF(STUFF(CAST(sjh.run_date as nvarchar(10)),5,0,'-'),8,0,'-') +' '+STUFF(STUFF(RIGHT(REPLICATE('0', 6) +  CAST(sjh.run_time as varchar(6)), 6), 3, 0, ':'), 6, 0, ':')),120)

where stop_execution_date IS NULL
and run_requested_date IS NOT NULL
;
GO
