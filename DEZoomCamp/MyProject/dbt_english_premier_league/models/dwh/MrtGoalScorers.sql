{{
    config(
        materialized='view'
    )
}}

with DimPlayerPerf as (
SELECT playerId, count(*) as GoalsScored
FROM {{ ref('DimPlayerPerf') }}
WHERE 1=1
  AND typeOfStat IN (1,2) --goal or by penalty
GROUP BY playerId
)

SELECT dp.PlayerName, dpp.GoalsScored
FROM DimPlayerPerf dpp
INNER JOIN {{ ref('DimPlayer') }} dp
  ON dpp.playerId = dp.playerId
ORDER BY dpp.GoalsScored DESC
