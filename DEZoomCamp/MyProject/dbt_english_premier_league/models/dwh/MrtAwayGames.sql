{{
    config(
        materialized='view'
    )
}}

SELECT 
  fm.*, 
  CAST(dms.possession as DECIMAL) as possession, 
  CAST(dms.shots as INT) as shots, 
  CAST(dms.shotsOnTarget as INT) as shotsOnTarget, 
  CAST(dms.passes as DECIMAL) as passes, 
  CAST(dms.yellowCards as INT) as yellowCards, 
  CAST(dms.redCards as INT) as redCards,
  dc.clubName
FROM {{ ref('FactMatch') }} fm
INNER JOIN {{ ref('DimMatchStats') }} dms
  ON fm.matchId = dms.matchId
  AND fm.awayTeamId = dms.clubId
INNER JOIN {{ ref('DimClub') }} dc 
  ON dms.clubId = dc.clubId