{{ config(
    materialized='table'
    ,partition_by={
      'field': 'seasonStartYear',
      'data_type': 'date',
      'granularity': 'year'
    }
    ,cluster_by = ['playerId','clubId']
    ) 
}}
 
with DimPlayerClub as 
(
  select *
  from {{ source('stg','DimPlayerClub') }}
)
select * from DimPlayerClub

