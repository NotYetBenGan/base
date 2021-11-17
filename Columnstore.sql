DECLARE @ObjectId NVARCHAR(50) = N'dbo.CCI' 

-- Row groups with details
SELECT 
	rg.state_desc, 
	rg.partition_number,
	rg.row_group_id,
	rg.total_rows, 
	c.name,
	cs.min_data_id,
	cs.max_data_id,
	rg.deleted_rows,
	rg.size_in_bytes/1024/1024 as [SizeMb],
	rg.trim_reason_desc as [Why less then 1048576],
	rg.transition_to_compressed_state_desc as [Why moved from deltastore],
	rg.delta_store_hobt_id,
	rg.created_time,
	rg.closed_time
FROM sys.dm_db_column_store_row_group_physical_stats rg
INNER JOIN sys.indexes i
	ON rg.index_id = i.index_id
	AND rg.object_id = i.object_id
INNER JOIN sys.partitions p
	ON rg.partition_number = p.partition_number
	AND rg.index_id = p.index_id
	AND rg.object_id = p.object_id
LEFT JOIN sys.column_store_segments cs
	ON rg.row_group_id = cs.segment_id
	AND p.partition_id = cs.partition_id
LEFT JOIN sys.columns c
	ON rg.object_id = c.object_id
	AND cs.column_id = c.column_id	
WHERE rg.object_id = object_id(@ObjectId)
	--AND c.name = 'Col1'
ORDER BY rg.partition_number, rg.row_group_id

--ALTER INDEX IDX_CS_CLUST ON dbo.CCI REORGANIZE PARTITION = 1 WITH (COMPRESS_ALL_ROW_GROUPS = ON)


-- Storage and pages
SELECT
	i.name as IndexName,
	p.index_id,
	p.partition_number,
	p.data_compression_desc,
	u.type_desc,
	u.total_pages,
	p.rows
FROM sys.allocation_units u
INNER JOIN sys.partitions p
	ON u.container_id = p.partition_id
INNER JOIN sys.indexes i
	ON p.index_id = i.index_id
	AND p.object_id = i.object_id
WHERE p.object_id = object_id(@ObjectId)
AND p.rows > 0
ORDER BY p.partition_number


-- Delta store details
SELECT
	pa.allocated_page_file_id as FileId,
	pa.allocated_page_page_id as PageId,
	pa.index_id, 
	pa.partition_id as partition_number, 
	pa.allocation_unit_type_desc as Type,
	pa.is_allocated,
	pa.is_iam_page,page_type,
	pa.page_type_desc, 
	ip.row_group_id,
	ip.internal_object_type_desc,
	ip.data_compression_desc,
	pa.rowset_id as partition_id
FROM sys.dm_db_database_page_allocations(db_id(),object_id(N'dbo.CCI'),NULL,NULL,'DETAILED') pa
INNER JOIN sys.internal_partitions ip
	ON pa.rowset_id = ip.partition_id
ORDER BY pa.rowset_id DESC, PageId


