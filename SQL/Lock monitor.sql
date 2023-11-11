SELECT
  DB_NAME(tl.resource_database_id) as DBName,
  tl.request_session_id,
  tl.resource_type,
  CASE tl.resource_type
    WHEN 'OBJECT' 
	THEN o.name
	ELSE OBJECT_NAME(p.OBJECT_ID)
  END as ObjectName,
  i.name as IndexName,
  tl.resource_type,
  tl.resource_subtype,
  tl.resource_description,
  tl.resource_associated_entity_id,
  tl.request_mode,
  tl.request_status,
  wt.blocking_session_id,
  wt.wait_duration_ms/1000.0 as WaitDurationInSec
FROM sys.dm_tran_locks as tl 
LEFT JOIN sys.dm_os_waiting_tasks wt 
	ON tl.lock_owner_address = wt.resource_address 
  --AND tl.request_status = 'WAIT'
LEFT JOIN sys.partitions p
	ON tl.resource_associated_entity_id = p.hobt_id
LEFT JOIN sys.objects o
	ON tl.resource_associated_entity_id = o.object_id
LEFT JOIN sys.indexes i
	ON COALESCE(o.object_id, p.object_id) = i.object_id
	AND COALESCE(p.index_id, 1) = COALESCE(i.index_id , 1)  --CLX by default
WHERE tl.resource_associated_entity_id > 0
	AND tl.resource_database_id = DB_ID()
	AND tl.request_session_id <> @@SPID
ORDER BY tl.request_session_id, tl.resource_associated_entity_id
