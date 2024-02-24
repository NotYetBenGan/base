{{
    config(
        materialized='table'
    )
}}

with fhv_tripdata  as (
    select *, 
        'FHV' as service_type
    from {{ ref('stg_fhv_tripdata') }}
), 
dim_zones as (
    select * from {{ ref('dim_zones') }}
    where borough != 'Unknown'
)
select 
    fhv.tripid,
    fhv.vendorid,
    fhv.pickup_locationid,
    fhv.dropoff_locationid,
    fhv.pickup_datetime,
    fhv.dropoff_datetime,
    fhv.sr_flag
from fhv_tripdata fhv
inner join dim_zones as pickup_zone
on fhv.pickup_locationid = pickup_zone.locationid
inner join dim_zones as dropoff_zone
on fhv.dropoff_locationid = dropoff_zone.locationid