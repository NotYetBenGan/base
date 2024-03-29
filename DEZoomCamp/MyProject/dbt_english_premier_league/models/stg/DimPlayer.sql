{{ config(
    materialized='table'
    ,cluster_by = 'playerId'
    ) 
}}
 
with DimPlayer as 
(
  select *
  from {{ source('stg','DimPlayer') }}
)
select * from DimPlayer

