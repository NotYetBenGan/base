{{ config(
    materialized='table'
    ,cluster_by = ['playerId','matchId']
    ) 
}}
 
with DimPlayerStats as 
(
  select *
  from {{ source('stg','DimPlayerStats') }}
)
select * from DimPlayerStats

