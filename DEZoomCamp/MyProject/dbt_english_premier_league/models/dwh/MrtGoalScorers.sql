{{
    config(
        materialized='view'
    )
}}

SELECT fm.seasonStartYear, dpp.*, dp.playerName
FROM {{ ref('FactMatch') }} fm 
INNER JOIN {{ ref('DimPlayerPerf') }} dpp
  ON fm.matchId = dpp.matchId 
INNER JOIN {{ ref('DimPlayer') }} dp
  ON dpp.playerId = dp.playerId
WHERE 1=1
  AND dpp.typeOfStat IN (1,2) --goal or by penalty

