USE [Monitor]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

create view [jobs].[statusFailed] as

/*
--https://stackoverflow.com/questions/10577676/how-to-obtain-failed-jobs-from-sql-server-agent-through-script
--This lists every job that has a failed step, so LEM_CORPORATE_TARGETS_IMPORT haspassed step 2 (evidently that is the one that is run) but failed step 1 in June
--2021-08-16 Similarly 2021-06-11 CORE_ORDER_BROADBAND failed at step 2, but since quits at step 1, so this query is seeing step 2 as the 'highest' last fail.
--so this needs to be rewritten to look for latest run time, not highest step, then latest run time.
SELECT   
		row_number() over (order by Job.exec_date desc) as sequence --cannot use order by in a view
		,@@servername monitor_source_server
        ,SysJobs.name as 'JOB_NAME'
        ,SysJobSteps.step_name as 'STEP_NAME'
        ,Job.run_status
        ,Job.exec_date
        ,Job.run_duration
		,Job.instance_id
        ,SysJobs.job_id
        ,Job.sql_message_id
        ,Job.sql_severity
        ,Job.message
        ,Job.server
        ,SysJobSteps.output_file_name
    FROM    (SELECT Instance.instance_id
        ,DBSysJobHistory.job_id
        ,DBSysJobHistory.step_id
        ,DBSysJobHistory.sql_message_id
        ,DBSysJobHistory.sql_severity
        ,DBSysJobHistory.message
        ,(CASE DBSysJobHistory.run_status
            WHEN 0 THEN 'Failed'
            WHEN 1 THEN 'Succeeded'
            WHEN 2 THEN 'Retry'
            WHEN 3 THEN 'Canceled'
            WHEN 4 THEN 'In progress'
        END) as run_status
        ,((SUBSTRING(CAST(DBSysJobHistory.run_date AS VARCHAR(8)), 5, 2) + '/'
        + SUBSTRING(CAST(DBSysJobHistory.run_date AS VARCHAR(8)), 7, 2) + '/'
        + SUBSTRING(CAST(DBSysJobHistory.run_date AS VARCHAR(8)), 1, 4) + ' '
        + SUBSTRING((REPLICATE('0',6-LEN(CAST(DBSysJobHistory.run_time AS varchar)))
        + CAST(DBSysJobHistory.run_time AS VARCHAR)), 1, 2) + ':'
        + SUBSTRING((REPLICATE('0',6-LEN(CAST(DBSysJobHistory.run_time AS VARCHAR)))
        + CAST(DBSysJobHistory.run_time AS VARCHAR)), 3, 2) + ':'
        + SUBSTRING((REPLICATE('0',6-LEN(CAST(DBSysJobHistory.run_time as varchar)))
        + CAST(DBSysJobHistory.run_time AS VARCHAR)), 5, 2))) AS 'exec_date'
        ,DBSysJobHistory.run_duration
        ,DBSysJobHistory.retries_attempted
        ,DBSysJobHistory.server
        FROM msdb.dbo.sysjobhistory DBSysJobHistory
        JOIN (SELECT DBSysJobHistory.job_id
            ,DBSysJobHistory.step_id
            ,MAX(DBSysJobHistory.instance_id) as instance_id
            FROM msdb.dbo.sysjobhistory DBSysJobHistory
            GROUP BY DBSysJobHistory.job_id
            ,DBSysJobHistory.step_id
            ) AS Instance ON DBSysJobHistory.instance_id = Instance.instance_id
        WHERE DBSysJobHistory.run_status = 0
        ) AS Job
    JOIN msdb.dbo.sysjobs SysJobs
       ON (Job.job_id = SysJobs.job_id)
    JOIN msdb.dbo.sysjobsteps SysJobSteps
       ON (Job.job_id = SysJobSteps.job_id AND Job.step_id = SysJobSteps.step_id)
	where SysJobs.name not like 'ZZ_%' and SysJobs.name not like 'ZZZ_%'
GO

*/
--that listed all failed steps.  this seems better:

with lastJobInstances as ( --this is the latest completed execution of a job (it wrote a step 0 to history)
select max(instance_id) instance_id, job_id
from msdb.dbo.sysjobhistory jh 
where step_id = 0
group by job_id
)
,lastFailedJobs as (  --detail of any latestJobInstances that failed
select jh.*
from msdb.dbo.sysjobhistory jh 
join lastJobInstances ljh on jh.instance_id = ljh.instance_id
and jh.run_status = 0
)
,lastFailedStepInstance as (	--most recent failed step in any job (highest failed step intance)
select max(instance_id) instance_id, job_id
from msdb.dbo.sysjobhistory jh 
where	jh.step_id > 0
		and jh.run_status = 0
group by job_id
)
,lastFailedSteps as (	--most recent (failed) step detail any job
select	lfs.*
from	lastFailedStepInstance	lfsi
join	msdb.dbo.sysjobhistory	lfs		on	lfsi.instance_id = lfs.instance_id
)


select	
		j.name	[jobName]
		,case j.description when 'No description available.' then '' else j.description end [description]
		,lfs.step_id
		,lfs.step_name
		,coalesce(lower(sjs.subsystem),'')		[subsystem]
		,coalesce(lower(sjs.database_name),'')	[database]
,case sjs.subsystem when 'TSQL' then sjs.command
		when 'SSIS' then
			case when left(sjs.command,10)='/ISSERVER' then reverse(substring(reverse(substring(coalesce(sjs.command,''),1,charindex('\""',coalesce(sjs.command,''),1)-1)),1,charindex('\',reverse(substring(coalesce(sjs.command,''),1,charindex('\""',coalesce(sjs.command,''),1)-1)),1)-1)) + ' (isserver)'
													--then	right(left(sjs.command,patindex('%dtsx%',sjs.command)+3),charindex('\',reverse(left(sjs.command,patindex('%dtsx%',sjs.command)+3)))-1) + ' (isserver)'
			when left(sjs.command,5)='/FILE' then	right(left(sjs.command,patindex('%dtsx%',sjs.command)+3),charindex('\',reverse(left(sjs.command,patindex('%dtsx%',sjs.command)+3)))-1) + ' (file)'
			else sjs.command end
		else '' end as command
		,lfs.message
		,msdb.dbo.agent_datetime(lfj.run_date,lfj.run_time) [jobStartDate]
		,case lfj.run_duration when 0 then '0' else trim('|' from trim ('0:' from 
		 right('0' + convert(varchar,(lfj.run_duration/86400)%24),2)+':'+
		 right('0' + convert(varchar,(lfj.run_duration/3600)%60),2)+':'+
		 right('0' + convert(varchar,(lfj.run_duration/60)%60),2)+':'+
		 right('0' + convert(varchar,lfj.run_duration%60),2) + '|')) end							[jobElapsedTime]
	 ,lfj.run_duration [jobElapsedSeconds]
		,msdb.dbo.agent_datetime(lfs.run_date,lfs.run_time) [stepStartDate]
		,case lfs.run_duration when 0 then '0' else trim('|' from trim ('0:' from 
		 right('0' + convert(varchar,(lfs.run_duration/86400)%24),2)+':'+
		 right('0' + convert(varchar,(lfs.run_duration/3600)%60),2)+':'+
		 right('0' + convert(varchar,(lfs.run_duration/60)%60),2)+':'+
		 right('0' + convert(varchar,lfs.run_duration%60),2) + '|')) end							[stepElapsedTime]
	 ,lfs.run_duration [stepElapsedSeconds]
		--,'|j',j.*,'|lfj',lfj.*,'|lfs',lfs.*
	,j.job_id
from	msdb.dbo.sysjobs		j
join	lastFailedJobs			lfj	on	j.job_id = lfj.job_id
join	lastFailedSteps			lfs	on	lfj.job_id = lfs.job_id
join (select * from monitor.jobs.fv_xp_sqlagent_enum_jobs() where state = 4) idle on j.job_id = idle.Job_ID
join	msdb.dbo.sysjobsteps	sjs	on (j.job_id = sjs.job_id and lfs.step_id = sjs.step_id  and lfs.step_name = sjs.step_name)

GO
