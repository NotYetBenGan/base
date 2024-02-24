{{ config(materialized='view') }}

-- with tripdata as 
-- (
--   select *,
--     row_number() over(partition by dispatching_base_num, pickup_datetime) as rn
--   from {{ source('staging','fhv_tripdata') }}
--   where dispatching_base_num is not null 
-- )
select
    -- identifiers
    {{ dbt_utils.generate_surrogate_key(['dispatching_base_num', 'pickup_datetime']) }} as tripid,
    cast(dispatching_base_num as string) as vendorid,
    cast(pulocationid as integer) as  pickup_locationid,
    cast(dolocationid as integer) as dropoff_locationid,

    -- timestamps
    cast(pickup_datetime as timestamp) as pickup_datetime,
    cast(dropoff_datetime as timestamp) as dropoff_datetime,

    -- trip info
    sr_flag,
from {{ source('staging','fhv_tripdata') }}
where cast(pickup_datetime as date) BETWEEN '2019-01-01' AND '2019-12-31'

{% if var('is_test_run', default=true) %}

    limit 100000000000

{% endif %}