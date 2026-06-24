
-- 1. Agg by Tables and Partitions and Partition Schemas 

DROP TABLE IF EXISTS ##Space
SELECT
  DB_NAME() AS 'DatabaseName'
  ,CONCAT(SCHEMA_NAME(o.schema_id),'.',OBJECT_NAME(p.OBJECT_ID)) AS 'TableName'
  ,p.object_id
  ,p.index_id AS 'IndexId'
  ,CASE
    WHEN p.index_id = 0 THEN 'HEAP'
    ELSE i.name
  END AS 'IndexName'
  ,ps.name AS 'PartitionSchemaName'
  ,p.partition_number AS 'PartitionNumber'
  ,prv_left.VALUE AS 'LowerBoundary'
  ,COALESCE(prv_right.VALUE, 10000000) AS 'UpperBoundary'
  ,CASE
    WHEN fg.name IS NULL THEN ds.name
    ELSE fg.name
  END AS 'FilegroupName'
  ,CAST(p.in_row_data_page_count /128 AS NUMERIC(18,2)) AS 'DataPages,MB' --Number of pages in use for storing in-row data in this partition
  ,CAST(p.used_page_count /128 AS NUMERIC(18,2)) AS 'UsedPages,MB' --Total number of pages used for the partition. Computed as in_row_used_page_count + lob_used_page_count + row_overflow_used_page_count
  ,CAST(p.reserved_page_count /128 AS NUMERIC(18,2)) AS 'ReservedPages,MB' --Total number of pages reserved for the partition. Computed as in_row_reserved_page_count + lob_reserved_page_count + row_overflow_reserved_page_count
  ,CASE
    WHEN p.index_id IN (0,1) THEN p.ROW_COUNT
    ELSE 0
  END AS 'RowCount'
  ,CASE
    WHEN p.index_id IN (0,1) THEN 'data'
    ELSE 'index'
  END AS 'Type'
INTO ##Space
FROM sys.dm_db_partition_stats p (NOLOCK)
INNER JOIN sys.objects o (NOLOCK)
  ON p.OBJECT_ID = o.OBJECT_ID
INNER JOIN sys.indexes i (NOLOCK)
  ON i.OBJECT_ID = p.OBJECT_ID AND i.index_id = p.index_id
INNER JOIN sys.data_spaces ds (NOLOCK)
  ON ds.data_space_id = i.data_space_id
LEFT JOIN sys.partition_schemes ps (NOLOCK)
  ON ps.data_space_id = i.data_space_id
LEFT JOIN sys.destination_data_spaces dds (NOLOCK)
  ON dds.partition_scheme_id = ps.data_space_id
  AND dds.destination_id = p.partition_number
LEFT JOIN sys.filegroups fg (NOLOCK)
  ON fg.data_space_id = dds.data_space_id
LEFT JOIN sys.partition_range_values prv_right (NOLOCK)
  ON prv_right.function_id = ps.function_id
  AND prv_right.boundary_id = p.partition_number
LEFT JOIN sys.partition_range_values prv_left (NOLOCK)
  ON prv_left.function_id = ps.function_id
  AND prv_left.boundary_id = p.partition_number - 1
WHERE 1=1
  AND OBJECTPROPERTY(p.OBJECT_ID, 'IsMSShipped') = 0 --exclude sys tables
  AND p.used_page_count > 0
  AND p.index_id IN (0,1,5)
  AND p.ROW_COUNT > 0

--SELECT * FROM ##Space