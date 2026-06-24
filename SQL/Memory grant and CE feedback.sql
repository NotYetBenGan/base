/*****************************/
-- Memory grant feedback and CE Feedback
/*****************************/

-- 0. Check if enabled
SELECT @@VERSION

SELECT
  name,
  value,
  value_for_secondary
FROM sys.database_scoped_configurations
WHERE name LIKE 'MEMORY_GRANT_FEEDBACK%'
  OR name IN ('CE_FEEDBACK', 'DOP_FEEDBACK')



-- 1. Memory grant feedback
SELECT
  pf.plan_id,
  pf.feature_id,
  pf.feature_desc,
  pf.state,
  pf.state_desc,
  pf.last_updated_time,
  qsqh.query_hint_text,
  NodeId              = CAST(j.NodeId AS int),
  GrantedMemoryKB     = CAST(j.AdditionalMemoryKB AS int),
  [Count]             = CAST(j.[Count] AS int),
  [Average]           = CAST(j.[Average] AS bigint),
  Variance            = CAST(j.Variance AS bigint)
FROM sys.query_store_plan_feedback AS pf
INNER JOIN sys.query_store_plan qsp
    ON pf.plan_id = qsp.plan_id
LEFT JOIN sys.query_store_query_hints qsqh
    ON qsp.query_id = qsqh.query_id
CROSS APPLY OPENJSON(pf.feedback_data)
WITH (
  NodeId              nvarchar(10)  '$.NodeId',
  AdditionalMemoryKB  nvarchar(20)  '$.AdditionalMemoryKB',
  [Count]             nvarchar(10)  '$.Count',
  [Average]           nvarchar(30)  '$.Average',
  Variance            nvarchar(30)  '$.Variance'
) AS j
WHERE 1=1
  AND pf.feature_desc IN ('Memory Grant Feedback')
  --AND JSON_VALUE(feedback_data, '$."Feedback hints"') <> ''
  --AND pf.plan_id IN (1190843)
  --AND CAST(j.AdditionalMemoryKB AS int) >= 10000000
ORDER BY qsp.query_id


--2. CE feedback
SELECT
  pf.plan_id,
  pf.feature_id,
  pf.feature_desc,
  pf.state,
  pf.state_desc,
  pf.last_updated_time,
  CAST(qsp.query_plan as XML) as query_plan,
  CASE WHEN pf.feature_desc = 'CE Feedback'
    THEN JSON_VALUE(feedback_data, '$."Feedback hints"')
  END AS CEFeedbackHintsInUse,
  qsqh.query_hint_text,
  CASE
    WHEN JSON_VALUE(feedback_data, '$."Feedback hints"') = 'Independence'
      THEN 'Tables predicates are fully independent (old CE model). The cardinality is calculated by multiplying the selectivities of all predicates'
    WHEN JSON_VALUE(feedback_data, '$."Feedback hints"') = 'Exponential backoff'
      THEN 'Tables predicates are partially correlated (new CE model). The cardinality is calculated using a variation on exponential backoff, ordering'
    WHEN JSON_VALUE(feedback_data, '$."Feedback hints"') = 'Min selectivity'
      THEN 'Tables predicates are fully correlated. The cardinality is calculated by using the minimum selectivities for all predicates'
    WHEN JSON_VALUE(feedback_data, '$."Feedback hints"') = 'Simple containment'
      THEN 'Join predicates are fully correlated (old CE model). Filter selectivity is calculated first, and then the join selectivity is factored in'
    WHEN JSON_VALUE(feedback_data, '$."Feedback hints"') = 'Base containment'
      THEN 'Join predicates are not correlated (new CE model). Join selectivity is calculated first, and then the filter selectivity is factored in'
  END AS CEFeedbackCorrelation
FROM sys.query_store_plan_feedback AS pf
INNER JOIN sys.query_store_plan qsp
    ON pf.plan_id = qsp.plan_id
LEFT JOIN sys.query_store_query_hints qsqh
    ON qsp.query_id = qsqh.query_id
WHERE 1=1
  AND pf.feature_desc IN ('CE Feedback')
  AND JSON_VALUE(feedback_data, '$."Feedback hints"') <> ''
  --AND pf.plan_id IN (1190843)
ORDER BY qsp.query_id