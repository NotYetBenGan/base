{{ config(
    materialized='table'
    ,cluster_by = 'stadiumId'
    ) 
}}
 
with DimStadium as 
(
  select *
  from {{ source('stg','DimStadium') }}
)
select * from DimStadium

