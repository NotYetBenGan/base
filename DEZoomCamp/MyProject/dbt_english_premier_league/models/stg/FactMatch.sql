{{ config(
    materialized='table'
    ,partition_by={
      'field': 'seasonStartYear',
      'data_type': 'date',
      'granularity': 'year'
    }
    ,cluster_by = 'matchId'
    ) 
}}
 
with FactMatch as 
(
  select *
  from {{ source('stg','FactMatch') }}
)
select * from FactMatch

