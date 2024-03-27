
{{ config(
    materialized='table'
    ,partition_by={
      "field": "seasonStartYear",
      "data_type": "date",
      "granularity": "year"
    }
    ) 
}}


 
with DimManagerClub as 
(
  select *
    --,row_number() over(partition by vendorid, tpep_pickup_datetime) as rn
  from {{ source('stg','DimManagerClub') }}
)
select * from DimManagerClub

