

-- 1st block to run
	DECLARE
		@DBName NVARCHAR(50) =  DB_NAME()
		,@SchemaTableName NVARCHAR(100) = 'dbo.TestOrders'




	/************************ Work with Pages ***********************/

	BEGIN
		DROP TABLE IF EXISTS #AllocationUnitIds
		SELECT 
			p.partition_id
			,p.object_id
			,au.allocation_unit_id 
			,au.type 
			,au.type_desc			-- Describes the type of allocation unit (e.g., IN_ROW_DATA, LOB_DATA)
		INTO #AllocationUnitIds
		FROM sys.allocation_units au
		INNER JOIN sys.partitions p 
			ON (au.type IN (1, 3) AND p.hobt_id = au.container_id) -- 1 = IN_ROW_DATA, 3 = ROW_OVERFLOW_DATA
			OR (au.type = 2 AND p.partition_id = au.container_id)  -- 2 = LOB_DATA
		WHERE p.object_id = OBJECT_ID('' + @SchemaTableName + '')

		-- SELECT * FROM #AllocationUnitIds 


		DROP TABLE IF EXISTS #MyPages
		SELECT 
			sa.allocation_unit_id 
			,sp.partition_id
			,bd.database_id
			,bd.file_id
			,bd.page_id
			,bd.page_type
			,bd.row_count
			,bd.free_space_in_bytes
			,bd.is_modified
		INTO #MyPages
		FROM sys.system_internals_allocation_units AS sa
		INNER JOIN sys.partitions AS sp
			ON sa.container_id = sp.partition_id
		INNER JOIN sys.dm_os_buffer_descriptors bd
			ON sa.allocation_unit_id = bd.allocation_unit_id
		WHERE 1=1
			AND sp.object_id = OBJECT_ID (@SchemaTableName)
			AND bd.is_modified = 1

		-- SELECT * FROM #MyPages 


		DROP TABLE IF EXISTS #MyPagesDetails
		SELECT 
			/*
			pd.page_lsn,					-- Last modification LSN on that page
			pd.fixed_length,				-- Length, in bytes, of fixed-size part of each row on the page
			pd.slot_count,					-- Total number of slots on the page (used + unused). For data pages equals number of rows
			pd.ghost_rec_count,				-- A number of ghost records that are marked for deletion
			pd.free_bytes,					-- Total bytes of free space currently available on the page
			pd.free_bytes_offset,			-- Offset in bytes to the start of free space at the end of the data area
			*/
			pd.*
		INTO #MyPagesDetails
		FROM #MyPages p
		CROSS APPLY sys.dm_db_page_info
		(
			p.database_id,	
			p.file_id,
			p.page_id,                      
			'DETAILED'   --  'DETAILED' or 'LIMITED'
		) pd
		WHERE p.page_type = 'DATA_PAGE'

		-- SELECT * FROM #MyPagesDetails

	END
	-- end of 1st block to run




	/************************ Work with Tran log ***********************/


		/*
		LSN (Log Sequence Number) in SQL Server is a 96-bit composite structure made up of three parts:
		- VLF sequence number (FileSeqNo) – 4 bytes
		- Block number (LogBlockOffset) – 4 bytes
		- Slot number (SlotId) – 2 bytes
		Because SQL Server doesn’t have a native 96-bit integer type (CPUs don’t natively support), 
		DMVs and functions (like sys.fn_dblog) expose LSNs as a string representation (nvarchar(64)), e.g.:
		For ex:

		FileSeqNo|LBOffset|SlId 
		---------|--------|----
		'0000002b:000001a3:0001'

		*/


	-- 2d block to run
	BEGIN
		-- Get @CurrentLSN - first parameter to sys.fn_dblog - for faster search
		DECLARE 
			@CurrentLSN NVARCHAR(64) 
			,@PrevLSN NVARCHAR(64)
			,@TransactionId NVARCHAR(50)
			,@PartitionId bigint
		
		SELECT 
			@CurrentLSN = page_lsn 
			,@PartitionId = partition_id
			--,@TransactionId = xdes_id '0000:00000000'
		FROM #MyPagesDetails
	
		SELECT @CurrentLSN = dbo.UDF_ConvertLSN(@CurrentLSN)

		 SELECT @CurrentLSN, @PartitionId --, @TransactionId,
		 
		--Create loop to come back to the LOP_BEGIN_XACT

		-- Get the first LSN of transaction (index seek)
		SELECT *
			--@PrevLSN = f.[Previous LSN],
			--@TransactionId = f.[Transaction ID]
		FROM sys.fn_dblog(@CurrentLSN, @CurrentLSN) f
		WHERE 1=1
			AND f.[Operation] in  (
				'LOP_MODIFY_ROW'  -- traditional locking
				,'LOP_INSYSXACT'  -- optimized locking
				)
			--AND f.[PartitionId] = @PartitionId  --doesn work for optimized locking
			--AND [Page ID] IN (<PageIds in hexademical>)

		SELECT @PrevLSN = dbo.UDF_ConvertLSN(@PrevLSN)

		 SELECT @PrevLSN, @TransactionId

		-- Read transaction log (index scan)
		DROP TABLE IF EXISTS #MyFullTransaction
		SELECT
			f.*
		INTO #MyFullTransaction
		FROM sys.fn_dblog(@PrevLSN, NULL) f
		WHERE 1=1
			AND f.[Transaction ID] = @TransactionId
			AND f.[PartitionId] = @PartitionId

		-- SELECT * FROM #MyFullTransaction


		-- IN_ROW_DATA
		DROP TABLE IF EXISTS #InRowData
		;WITH InRowData AS
        (
		SELECT
			f.[Transaction Id] AS TransactionId
			,f.AllocUnitId
			,f.PartitionId
			,au.[object_id] AS [ObjectId]
			,au.[type_desc] AS [TypeDesc]
			,CONVERT(BIGINT, CONVERT(VARBINARY, SUBSTRING(f.[Page ID], 6, 8), 2)) AS PageId  --(8 characters, 4 bytes in hexadecimal)
			,f.[Slot ID] AS SlotId
			,f.[RowLog Contents 0] 
			,f.[RowLog Contents 1]
			,f.[RowLog Contents 2]
			,f.[RowLog Contents 3]
		FROM #MyFullTransaction f
		INNER JOIN #AllocationUnitIds au 
			ON f.AllocUnitId = au.allocation_unit_id
		WHERE 1=1 
			AND au.[type_desc] = 'IN_ROW_DATA'
		)

		SELECT 
			TransactionId
			,AllocUnitId
			,PartitionId
			,ObjectId
			,TypeDesc
			,PageId
			,SlotId
			,ROW_NUMBER() OVER(ORDER BY PageId, SlotId) AS RowId
			,[RowLog Contents 0]
			,[RowLog Contents 1]
			,[RowLog Contents 2]
			,[RowLog Contents 3]
		INTO #InRowData
		FROM InRowData

		-- SELECT * FROM #InRowData 
	
	END
	-- end of 2d block to run
