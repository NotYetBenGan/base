{{ config(
    materialized='table'
    ,partition_by={
      'field': 'seasonStartYear',
      'data_type': 'date',
      'granularity': 'year'
    }
    ,cluster_by = ['managerId','clubId']
    ) 
}}
 
with DimManagerClub as 
(
  select *
  from {{ source('stg','DimManagerClub') }}
)
select * from DimManagerClub

