SELECT TOP 50 
  DB_NAME(qp.dbid) as DbName,
  qs.last_execution_time as LastExecutionTime,
  SUBSTRING(qt.text, (qs.statement_start_offset/2)+1, 
    ((
	  CASE qs.statement_end_offset
	    WHEN - 1 THEN DATALENGTH(qt.text)
	    ELSE qs.statement_end_offset
	  END - qs.statement_start_offset)/2)+1) as SQL,
  qp.query_plan as QueryPlan,
  qs.execution_count as ExecutionCount,                   
  (qs.total_logical_reads +qs.total_logical_writes)/qs.execution_count as AvgIOInPages,
  qs.total_logical_reads/qs.execution_count as AvgReadsInPages,
  qs.total_logical_writes/qs.execution_count as AvgWritesInPages,
  qs.total_worker_time/(qs.execution_count*1000000.0) as AvgCPUTimeInSec,
  qs.total_worker_time/1000000.0 as TotalCPUTimeInSec,        -- Amount of CPU cycles (in sec) spent by the thread on a particular processor/CPU
  qs.max_worker_time/1000000.0 as MaxCPUTimeInSec,
  qs.total_dop/qs.execution_count as AvgDOP,
  qs.total_elapsed_time/(qs.execution_count*1000000.0) as AvgElapsedTimeInSec,
  qs.total_elapsed_time/1000000.0 as TotalElapsedTimeInSec,   -- The time from start to end. total_worker_time (CPU) + suspended time (waiting for resource)
  qs.max_elapsed_time/1000000.0 as MaxElapsedTimeInSec,
  qs.total_rows,                                              -- Total number of rows returned by the query (for all executions)
  qs.max_rows    
FROM sys.dm_exec_query_stats qs 
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) qt
CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle) qp
WHERE
  qp.dbid = DB_ID()
  AND (qs.max_worker_time/1000000.0 > 180   -- highly parallel queries
    OR qs.max_elapsed_time/1000000.0 > 180  -- slow single threaded queries
      )
ORDER BY AvgIOInPages DESC
