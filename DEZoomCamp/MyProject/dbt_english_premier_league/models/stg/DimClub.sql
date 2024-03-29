{{ config(
    materialized='table'
    ,cluster_by = 'clubId'
    ) 
}}
 
with DimClub as 
(
  select *
  from {{ source('stg','DimClub') }}
)
select * from DimClub

