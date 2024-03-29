{{ config(
    materialized='table'
    ,cluster_by = 'managerId'
    ) 
}}
 
with DimManager as 
(
  select *
  from {{ source('stg','DimManager') }}
)
select * from DimManager

