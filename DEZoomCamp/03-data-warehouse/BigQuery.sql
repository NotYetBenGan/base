		-- Creating external table referring to gcs path
		CREATE OR REPLACE EXTERNAL TABLE `theta_byte_412611_bigquery_dataset_taxi_rides_ny.green_tripdata_2022`
		OPTIONS (
		  format = 'parquet',
		  uris = ['gs://theta-byte-412611-terraform-bucket/green_tripdata_2022-*.parquet']
		);

		-- Create a non partitioned table from external table
		CREATE OR REPLACE TABLE theta_byte_412611_bigquery_dataset_taxi_rides_ny.green_tripdata_2022_non_partitoned AS
		SELECT * FROM theta_byte_412611_bigquery_dataset_taxi_rides_ny.green_tripdata_2022;


		--Q1
		SELECT COUNT(*) 
		FROM theta_byte_412611_bigquery_dataset_taxi_rides_ny.green_tripdata_2022_non_partitoned


		--Q2
		SELECT COUNT(distinct PULocationID) 
		FROM theta_byte_412611_bigquery_dataset_taxi_rides_ny.green_tripdata_2022

		SELECT COUNT(distinct PULocationID) 
		FROM theta_byte_412611_bigquery_dataset_taxi_rides_ny.green_tripdata_2022_non_partitoned


		--Q3
		SELECT COUNT(*) 
		FROM theta_byte_412611_bigquery_dataset_taxi_rides_ny.green_tripdata_2022
		WHERE fare_amount = 0


		--Q4
		-- Create a partitioned table from external table
		CREATE OR REPLACE TABLE theta_byte_412611_bigquery_dataset_taxi_rides_ny.green_tripdata_2022_partitoned_clustered
		PARTITION BY  DATE(lpep_pickup_datetime)
		CLUSTER BY PUlocationID AS
		SELECT * FROM theta_byte_412611_bigquery_dataset_taxi_rides_ny.green_tripdata_2022;


		--Q5
		SELECT distinct PULocationID 
		FROM theta_byte_412611_bigquery_dataset_taxi_rides_ny.green_tripdata_2022
		WHERE lpep_pickup_datetime between '2022-06-01' AND '2022-06-30'

		SELECT distinct PULocationID 
		FROM theta_byte_412611_bigquery_dataset_taxi_rides_ny.green_tripdata_2022_partitoned_clustered
		WHERE lpep_pickup_datetime between '2022-06-01' AND '2022-06-30'