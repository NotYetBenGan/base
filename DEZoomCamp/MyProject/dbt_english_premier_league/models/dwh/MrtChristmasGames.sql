{{
    config(
        materialized='view'
    )
}}

with FactMatches as (
    SELECT fm.stadiumId, count(*) as gamesPlayed
    FROM {{ ref('FactMatch') }} fm
    WHERE 1=1
        AND (fm.matchDate like '%-12-24' or fm.matchDate like '%-12-25' or fm.matchDate like '%-12-26')
    GROUP BY fm.stadiumId
)

SELECT ds.stadiumName, fm.gamesPlayed
FROM FactMatches fm
INNER JOIN {{ ref('DimStadium') }} ds
    ON fm.stadiumId = ds.stadiumId
ORDER BY fm.gamesPlayed DESC
