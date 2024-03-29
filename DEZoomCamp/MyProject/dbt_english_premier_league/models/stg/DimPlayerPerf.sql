{{ config(
    materialized='table'
    ,cluster_by = ['playerId','matchId']
    ) 
}}
 
with DimPlayerPerf as 
(
  select *
  from {{ source('stg','DimPlayerPerf') }}
)
select * from DimPlayerPerf

