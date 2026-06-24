
-- 0. Check if QS is enabled

SELECT 
    d.name,
    d.is_query_store_on
FROM sys.databases AS d 


-- 1. General query to get query_id, plan_id, etc from SP call

;WITH query_store_query AS (
  SELECT
    qsq.query_id,
    qsq.query_text_id,
    o.name
  FROM sys.query_store_query qsq 
  INNER JOIN sys.objects o ON qsq.object_id = o.object_id
  WHERE 1=1
    AND qsq.last_execution_time >= DATEADD(day, -3, GETDATE())
),

query_store_plan AS (
  SELECT
    qsp.plan_id, qsp.query_id, qsp.is_forced_plan, qsp.is_parallel_plan, qsp.plan_forcing_type_desc
  FROM sys.query_store_plan qsp 
  WHERE 1=1
    AND qsp.last_execution_time >= DATEADD(day, -3, GETDATE())
),

query_store_runtime_state AS (
  SELECT
    qsrs.plan_id,
    qsrs.count_executions,
    qsrs.min_duration,
    qsrs.avg_duration,
    qsrs.max_duration,
    qsrs.min_rowcount,
    qsrs.max_rowcount,
    qsrs.last_execution_time
  FROM sys.query_store_runtime_stats qsrs  
  WHERE 1=1
    AND qsrs.last_execution_time >= DATEADD(day, -3, GETDATE())
    AND qsrs.min_rowcount >= 0
    AND qsrs.max_rowcount > 1
)

SELECT TOP 100
  qsq.query_id,
  MAX(qsq.name) AS NameSP,
  MAX(qsq.query_text_id) AS query_text_id,
  qsp.plan_id,
  MAX(qsp.is_forced_plan + 0) AS is_forced,
  MAX(qsp.plan_forcing_type_desc) AS plan_forcing_type_desc,
  MAX(qsp.is_parallel_plan + 0) AS is_parallel_plan,
  --CAST(MAX(qsp.query_plan) AS XML) AS query_plan,
  CAST(MIN(qsrs.min_duration) / 1000.0 AS DECIMAL(15,2)) AS min_duration_ms,
  CAST(AVG(qsrs.avg_duration) / 1000.0 AS DECIMAL(15,2)) AS avg_duration_ms,
  CAST(MAX(qsrs.max_duration) / 1000.0 AS DECIMAL(15,2)) AS max_duration_ms,
  MAX(qsrs.last_execution_time) AS last_execution_time,
  MIN(qsrs.min_rowcount) AS min_rowcount_output,
  MAX(qsrs.max_rowcount) AS max_rowcount_output
FROM query_store_query qsq
INNER JOIN query_store_plan qsp ON qsp.query_id = qsq.query_id
INNER JOIN query_store_runtime_state qsrs ON qsp.plan_id = qsrs.plan_id
WHERE 1=1
GROUP BY qsq.query_id, qsp.plan_id
HAVING 1=1
 -- AND MAX(qsq.name) LIKE '%%'
ORDER BY max_duration_ms DESC;



-- 2. Detailization by Operators 

;WITH base AS
(
  SELECT
    plan_id,
    query_id,
    plan_group_id,
    engine_version,
    compatibility_level,
    query_plan_hash,
    --query_plan,
    TRY_CAST(query_plan AS XML) AS query_plan,
    is_online_index_plan,
    is_trivial_plan,
    is_parallel_plan,
    is_forced_plan,
    is_natively_compiled,
    force_failure_count,
    last_force_failure_reason,
    last_force_failure_reason_desc,
    count_compiles,
    initial_compile_start_time,
    last_compile_start_time,
    last_execution_time,
    avg_compile_duration,
    last_compile_duration,
    plan_forcing_type,
    plan_forcing_type_desc
  FROM sys.query_store_plan p
)

SELECT
  p.plan_id,
  n.value('@NodeId','int')                              AS NodeId,
  n.value('@PhysicalOp','nvarchar(50)')                 AS PhysicalOp,
  n.value('@LogicalOp','nvarchar(50)')                  AS LogicalOp,
  n.value('@EstimateRows','float')                      AS EstRows,
  n.value('@EstimateIO','float')                        AS EstimateIO,
  n.value('@EstimateCPU','float')                       AS EstimateCPU,
  n.value('@AvgRowSize','float')                        AS AvgRowSize,
  n.value('@EstimatedTotalSubtreeCost','float')         AS EstimatedTotalSubtreeCost,
  n.value('@EstimatedExecutionMode','nvarchar(50)')      AS EstimatedExecutionMode,
  n.value('@Parallel','float')                          AS Parallel
FROM base p
CROSS APPLY p.query_plan.nodes(
  'declare namespace p="http://schemas.microsoft.com/sqlserver/2004/07/showplan";
  //p:RelOp'
) AS x(n)
WHERE 1=1
  --AND qsp.query_id IN (1487431)
  AND p.plan_id IN (192)
ORDER BY NodeId
