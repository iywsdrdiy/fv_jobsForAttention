# fv_jobsForAttention
Detail currently executing or failed jobs

## fv_xp_sqlagent_enum_jobs
return xp_sqlagent_enum_jobs as a view

The msdb.dbo.sys job tables can take you so far, but they only hold detail from the last time a step finished: they don't actually tell you what is running now. This is possibly why the history you can get to via the Job Activity Monitor only shows you the previous step, never the currently running one,

This undocumented stored procedure will show what is executing now, without making assumptions by looking at the last recorded step and attempting to deduce the current state. Without this, if you want to work out the current executing step of a job you'll have to get into all sorts of contortions unless none of your jobs do anything but simple sequential step on success and quit on failure.

The problems are first that it is a stored procedure and really, wanting its output as a view, this is the preferable way to achieve that.

#### Problems
+ The privileges to run [fv_xp_sqlagent_enum_jobs](https://github.com/iywsdrdiy/fv_jobsForAttention/blob/main/fv_xp_sqlagent_enum_jobs.sql) are quite high. I can't remember what, but I had to beg for them, and I cannot pass them on to my users. Im not allowed to add to msdb (perhaps I shouldn't anyway) and I have played around with `execute as` to no avail: that only works in the current database. In the end, to provide output from this xsp, I have had to resort to a job that updates a table at regular frequency. I don't like that but they are happy with the result (it is more than they had before).
+ [statusFailed](https://github.com/iywsdrdiy/fv_jobsForAttention/blob/main/statusFailed.sql) has the regular botch just to consider `max(instance_id)` of `msdb.dbo.sysjobhistory`
