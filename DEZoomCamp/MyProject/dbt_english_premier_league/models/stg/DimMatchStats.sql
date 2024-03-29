{{ config(
    materialized='table'
    ,cluster_by = ['matchId', 'clubId']
    ) 
}}
 
with DimMatchStats as 
(
  select *
  from {{ source('stg','DimMatchStats') }}
)
select * from DimMatchStats

