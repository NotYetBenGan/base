SELECT 
  DB_NAME(s.database_id) as DbName,
  s.session_id,
  p.kpid as windows_thread_id,
  p.ecid as subthread_id,
  s.host_name,
  s.program_name,
  s.login_name,
  r.wait_type,
  r.wait_time,
  p.status,
  mg.dop,
  mg.granted_memory_kb,
  p.open_tran as IsOpenTran,
  p.waitresource,
  r.start_time,
  SUBSTRING(st.text, r.statement_start_offset / 2, 
  (
    CASE 
      WHEN r.statement_end_offset = -1 
      THEN DATALENGTH(st.text)
      ELSE r.statement_end_offset
    END - r.statement_start_offset) / 2
  ) AS StatementExecuting,
  ib.event_info as ParentStatementExecuting,
  CAST(tqp.query_plan AS XML) as ActualPlan,
  CAST(rtp.query_plan as XML) as RuntimePlan
FROM sys.dm_exec_sessions s
INNER JOIN sys.sysprocesses p
  ON s.session_id = p.spid
  AND s.database_id = p.dbid
INNER JOIN sys.dm_exec_requests r
  ON s.session_id = r.session_id
LEFT JOIN sys.dm_exec_query_memory_grants mg
  ON s.session_id = mg.session_id
CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) st
CROSS APPLY sys.dm_exec_input_buffer(s.session_id, NULL) ib
OUTER APPLY sys.dm_exec_query_statistics_xml(s.session_id) rtp --trace flag 7412 should be enabled
OUTER APPLY sys.dm_exec_text_query_plan
(
  r.plan_handle,
  r.statement_start_offset,
  r.statement_end_offset
) AS tqp
WHERE s.is_user_process = 1
  AND s.database_id = DB_ID()
  AND s.session_id > 50
  AND s.session_id <> @@SPID
  --AND s.session_id = 51
ORDER BY r.session_id
