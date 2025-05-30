
CREATE OR ALTER PROCEDURE [dbo].[ResurrectionOfLostData]
	@SchemaTableName	NVARCHAR(100)
	,@HasBlobData		BIT = 0
	,@IsDebugMode		BIT = 1

	--Create test table https://raresql.com/2011/10/22/how-to-recover-deleted-data-from-sql-sever/
	--Reading Tran log https://www.sqlservercentral.com/articles/reading-sql-servers-transaction-log
	--StackOverflow discussion https://stackoverflow.com/questions/69981365/how-to-fix-a-stored-procedure-that-can-recover-deleted-data

	/**********Limitations**********/
	/* Heap only, one row only */
AS
 
BEGIN
--*/
	DECLARE
		@DBName NVARCHAR(50) =  DB_NAME()
		,@DateFrom DATETIME = DATEADD(HOUR,-1,GETDATE())
		,@DateTo DATETIME = GETDATE()
	/* 
		,@SchemaTableName NVARCHAR(100) = 'dbo.Variable'
	*/

	--SET @DateFrom = ISNULL(@DateFrom, DATEADD(HOUR,-1,GETDATE()))
	--SET @DateTo = ISNULL(@DateTo, GETDATE())
 
	IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES 
		WHERE [TABLE_SCHEMA] + '.' + [TABLE_NAME] = @SchemaTableName
		AND TABLE_CATALOG = @DBName
		)
	BEGIN
		RAISERROR (N'There is no table %s in DB %s', 16, 1, @SchemaTableName, @DBName);
		--RETURN
	END


	/************************ Work with Tran log ***********************/
	BEGIN
		DROP TABLE IF EXISTS #AllocationUnitIds
		SELECT 
			p.[partition_id],
			p.[object_id],
			au.[Allocation_unit_id], 
			au.[type], 
			au.[type_desc]
		INTO #AllocationUnitIds
		FROM sys.allocation_units au
		INNER JOIN sys.partitions p 
			ON (au.type IN (1, 3) AND p.hobt_id = au.container_id) -- 1 = IN_ROW_DATA, 3 = ROW_OVERFLOW_DATA
			OR (au.type = 2 AND p.partition_id = au.container_id)  -- 2 = LOB_DATA
		WHERE p.object_id = object_ID('' + @SchemaTableName + '')

		-- select * from #AllocationUnitIds 


		-- Get the first row of transaction from tran log - most time consuming operation in SP - ~10sec
		DROP TABLE IF EXISTS #TransactionWithDelete
		SELECT DISTINCT 
			f.[Transaction ID], f.[Transaction Name], f.[Current LSN], f.[Begin Time]
		INTO #TransactionWithDelete
		FROM sys.fn_dblog(NULL, NULL) f --replace with fn_full_db_log?
		WHERE f.[Context] IN ('LCX_NULL') 
			AND f.[Operation] IN ('LOP_BEGIN_XACT')  
			AND f.[Transaction Name] IN ('DELETE','user_transaction')
			AND CAST(f.[Begin Time] as DATETIME) BETWEEN @DateFrom AND @DateTo

		-- select * from #TransactionWithDelete order by CAST([Begin Time] as DATETIME) desc



		-- Get StartLSN in VARCHAR - first parameter to sys.fn_dblog - for fast search
		DECLARE @StartLSN NVARCHAR(25) = (SELECT TOP 1 [Current LSN] FROM #TransactionWithDelete ORDER BY CAST([Begin Time] as DATETIME) DESC)
	
		DECLARE @N1 BIGINT = CONVERT(varbinary,SUBSTRING(@StartLSN, 1, 8),2),
				@N2 BIGINT = CONVERT(varbinary,SUBSTRING(@StartLSN, 10, 8),2),
				@N3 BIGINT = CONVERT(varbinary,SUBSTRING(@StartLSN, 19, 4),2)

		SELECT @StartLSN = CAST(@N1 AS VARCHAR) + ':' + CAST(@N2 AS VARCHAR) + ':' + CAST(@N3 AS VARCHAR)


		/*
		SUBSTRING(f.[RowLog Contents 0], 1, 1) = Status Bits A (first byte) bitmap values:
		Bit	Hex Value	Meaning
		0	0x01	Row is a primary record (not a ghost record). If this bit is 0, the row may be a ghosted (deleted) record.
		1	0x02	Row is a ghost record. Ghost records are soft-deleted rows marked for garbage collection.
		2	0x04	Row is a forwarded record. Used in heaps when a row moves due to an update, leaving a forwarding pointer in the original location.
		3	0x08	Row has a forwarding pointer. Indicates the row is a pointer to another record in a heap.
		4	0x10	Row is part of a heap and has a versioning pointer (Bit A). Used for snapshot isolation and versioning in tempdb.
		5	0x20	Row has NULL bitmap. Indicates that the row has a NULL bitmap, meaning one or more columns may contain NULL values.
		6	0x40	Row has variable-length columns. If set, the row contains variable-length column data (like VARCHAR, NVARCHAR, VARBINARY).
		7	0x80	Row has been compressed. Used when row-level data compression is enabled.
		*/


		DROP TABLE IF EXISTS #MyTransaction
		SELECT
			f.[Transaction ID] AS [TransactionId]	
			,au.[partition_id] AS [PartitionId]
			,au.[object_id] AS [ObjectId]
			,f.[AllocUnitID] AS [AllocUnitId] 
			,au.[type_desc] AS [TypeDesc]
			,f.[Context]
			,f.[Operation]
			,CASE 
				WHEN f.[Description] LIKE '%Deallocated%' 
				THEN RIGHT(f.[Description], LEN(f.[Description]) - (CHARINDEX('Deallocated',f.[Description], 1) + LEN('Deallocated'))) 
			 END AS [DeallocateSpaceLOBConsolidatedPageID]
			,f.[PAGE ID] as [TextMixLOBConsolidatedPageID]
			,f.[Slot ID] as [SlotId]
			,CAST(SUBSTRING(f.[RowLog Contents 0], 15, LEN(f.[RowLog Contents 0])) as VARBINARY(8000)) AS [RowLogHexValue] --what is this?
			,CONVERT(INT,SUBSTRING(f.[RowLog Contents 0],7,2)) as [LinkId]
			,f.[RowLog Contents 0] 
		INTO #MyTransaction
		FROM sys.fn_dblog(@StartLSN, NULL) f
		INNER JOIN #AllocationUnitIds au 
			ON f.[AllocUnitId] = au.allocation_unit_id
		WHERE 1=1 
			AND 
			(
				f.[Context] IN ('LCX_MARK_AS_GHOST', 'LCX_HEAP', 'LCX_CLUSTERED')   -- IN_ROW_DATA
			 OR f.[Context] IN  ('LCX_PFS', 'LCX_TEXT_MIX') 						-- BLOB DATA TYPEs
			 OR f.[Operation] IN ('LOP_DELETE_ROWS')								-- IN_ROW_DATA
			 OR f.[Operation] IN  ('LOP_MODIFY_ROW') 								-- BLOB DATA TYPEs
			 OR SUBSTRING(f.[RowLog Contents 0], 1, 1) 
			 	IN (0x10,  -- Row versioning is enabled - TBD - check
			 		0x30,  -- + Row has NULL bitmap 
			 		0x70)  -- + Row has variable-length columns
			 OR f.[Description] LIKE '%Deallocated%'
			)
			AND f.[Context] NOT IN ('LCX_GAM')
			--All transactions with DELETE
			AND f.[TRANSACTION ID] IN 
			(
				SELECT DISTINCT [TRANSACTION ID]
				FROM #TransactionWithDelete
			)

		-- SELECT * FROM #MyTransaction f


		-- IN_ROW_DATA
		DROP TABLE IF EXISTS #RowLogContents
		SELECT
			f.[RowLog Contents 0] 
			,f.[PartitionId]
			,f.[ObjectId]
			,f.[AllocUnitId] 
			,f.[TypeDesc]
			,f.[TransactionId]
			,f.[SlotId]
		INTO #RowLogContents
		--need sysadmin permission; tran log file cleaning is disabled, while sys.fn_dblog is running
		FROM #MyTransaction f
		INNER JOIN #AllocationUnitIds au 
			ON f.[AllocUnitId] = au.allocation_unit_id
			AND au.[type] = 1 -- IN_ROW_DATA
		WHERE 1=1 
			AND f.[Context] IN ('LCX_MARK_AS_GHOST', 'LCX_HEAP') 
			AND f.[Operation] IN ('LOP_DELETE_ROWS') 
			AND SUBSTRING(f.[RowLog Contents 0], 1, 1) IN (0x10,0x30,0x70) 
			AND f.[TypeDesc] = 'IN_ROW_DATA'

		IF @IsDebugMode = 1
			SELECT * FROM #RowLogContents
	END

	/************************ Work with Data page ***********************/
	/*
	--Fixed
	1 Byte : Status Bit A
	1 Byte : Status Bit B
	2 Bytes : Fixed length size
	n Bytes : Fixed length data
	2 Bytes : Total Number of Columns
	(#cols/8) Bytes : NULL Bitmap (1 bit for each column as 1 indicates that the column is null and 0 indicate that the column is not null)
	--Var
	2 Bytes : Number of variable-length columns
	...
	*/

	DROP TABLE IF EXISTS #ColumnDataHexValue 
	CREATE TABLE #ColumnDataHexValue 
	(
		[RowId]            INT,
		[RowLogContents]   VARBINARY(MAX),
		[Name]             SYSNAME,
		[DataTypeName]	   VARCHAR(50),
		[NullBit]          SMALLINT,
		[SystemTypeId]     TINYINT,
		[BitPos]           TINYINT,
		[Precision]        TINYINT,
		[Scale]            TINYINT,
		[IsNull]           INT,
		[ColumnValueStartPosition]  INT,
		[ColumnLength]     INT,
		[HexValue]         VARBINARY(MAX),
		[SlotId]           INT,
		[Update]           INT
	)
	/************************ Loop by rows. Start ***********************/
	BEGIN
		/**********Check for IN_ROW_DATA. Start************/
		BEGIN
			DECLARE 
				@FixedLengthSize SMALLINT,
				@TotalNumOfCols INT,
				@TotalNullBitmapSize INT,
				@VarNumOfCols SMALLINT

			SELECT
				@FixedLengthSize = dbo.UDF_GetIntFromNtoMBytes([RowLog Contents 0], 3, 2) -- third and fourth bytes
			FROM #RowLogContents

			SELECT
				@TotalNumOfCols = dbo.UDF_GetIntFromNtoMBytes([RowLog Contents 0], @FixedLengthSize + 1, 2) -- 2 bytes after Fixed-length data
			FROM #RowLogContents

			SELECT
				@TotalNullBitmapSize = CEILING(@TotalNumOfCols /8.0)
			FROM #RowLogContents

			SELECT 
				@VarNumOfCols = dbo.UDF_GetIntFromNtoMBytes([RowLog Contents 0], @FixedLengthSize + 1 + 2 + @TotalNullBitmapSize, 2) -- next 2 bytes after @TotalNullBitmapSize
			FROM #RowLogContents

			  SELECT @FixedLengthSize, @TotalNumOfCols, @TotalNullBitmapSize, @VarNumOfCols
			  --SELECT * FROM #RowLogContents


	   
			DROP TABLE IF EXISTS #BitTable
			CREATE TABLE #BitTable 
			(
				[ID] INT,
				[BitValue] INT
			)
			--Create table to set the bit position of one byte.
 
			INSERT INTO #BitTable
			SELECT 0,2 UNION ALL
			SELECT 1,2 UNION ALL
			SELECT 2,4 UNION ALL
			SELECT 3,8 UNION ALL
			SELECT 4,16 UNION ALL
			SELECT 5,32 UNION ALL
			SELECT 6,64 UNION ALL
			SELECT 7,128

			--select * from #BitTable


			--Create table to collect the row data.
			DROP TABLE IF EXISTS #DeletedRows
			CREATE TABLE #DeletedRows 
			(
				[RowId]					INT IDENTITY(1,1),
				[PartitionId]			BIGINT,	
				[ObjectId]				INT,
				[RowLogContents]		VARBINARY(8000),
				[StatusBitA]			VARBINARY(2),
				[StatusBitB]			VARBINARY(2),
				[FixedLengthSize]		SMALLINT,
				[FixedLengthData]		VARBINARY(8000),
				[TotalNumOfCols]		SMALLINT,
				[TotalNullBitmapSize]	SMALLINT,
				[TotalNullBytes]		VARBINARY(8000),
				[TotalNullBitMap]		VARCHAR(MAX),  
				[VarNumOfCols]			SMALLINT,
				[VarColsOffsetArray]	VARBINARY(8000),
				[VarLengthDataStart]	SMALLINT,
				[SlotId]				INT,
			)

			/*
			...
			2 Bytes : Number of variable-length columns
			n Bytes : Column offset array (2x variable length column)
			n Bytes : Data for variable length columns
			*/
			;WITH RowData AS (
			SELECT 
				[PartitionId]
				,[ObjectId]
				--Fixed
				,[RowLog Contents 0] AS RowLogContents 
				,SUBSTRING([RowLog Contents 0], 1,1) AS [StatusBitA]
				,SUBSTRING([RowLog Contents 0], 2,1) AS [StatusBitB]
				,@FixedLengthSize AS [FixedLengthSize]
				,SUBSTRING([RowLog Contents 0], 5, @FixedLengthSize - 4) AS [FixedLengthData]
				,@TotalNumOfCols AS [TotalNumOfCols] --2 bytes after Fixed-length data
				,@TotalNullBitmapSize AS TotalNullBitmapSize
				,SUBSTRING([RowLog Contents 0], @FixedLengthSize + 3, @TotalNullBitmapSize) AS [TotalNullBytes] --next (#col/8) bytes after [TotalNumOfCols]
				--Var
				,@VarNumOfCols AS [VarNumOfCols] --next 2 bytes after [TotalNullBytes]
				--[VarColsOffsetArray] = next bytes [VarNumOfCols]*2 
				,SUBSTRING([RowLog Contents 0], @FixedLengthSize + 3 + @TotalNullBitmapSize + 2, @VarNumOfCols * 2) AS [VarColsOffsetArray] 
				,@FixedLengthSize + 3 + @TotalNullBitmapSize + @VarNumOfCols * 2 + 1 AS [VarLengthDataStart] --next bytes after [VarColsOffsetArray]
				,[SlotId]
			FROM #RowLogContents
			),
 
			--Generate sequence from 1 to 256 here
			N1 (n) AS (SELECT 1 UNION ALL SELECT 1),
			N2 (n) AS (SELECT 1 FROM N1 AS X, N1 AS Y),
			N3 (n) AS (SELECT 1 FROM N2 AS X, N2 AS Y),
			N4 (n) AS (SELECT ROW_NUMBER() OVER(ORDER BY X.n)
					   FROM N3 AS X, N3 AS Y) 
  
			INSERT INTO #DeletedRows
			SELECT
				[PartitionId]
				,[ObjectId]
				,[RowLogContents]
				,[StatusBitA]
				,[StatusBitB]
				,[FixedLengthSize]
				,[FixedLengthData]
				,[TotalNumOfCols]
				,[TotalNullBitmapSize]
				,[TotalNullBytes]
				,[TotalNullBitMap] = (REPLACE(STUFF --Get the NULL value against each column (1 means NULL, 0 means NOT NULL)
				(
					(
						SELECT ',' +
						(CASE 
							WHEN [Id] = 0 
							THEN CONVERT(NVARCHAR(1),(SUBSTRING([TotalNullBytes], [n], 1) % 2))  
							ELSE CONVERT(NVARCHAR(1),((SUBSTRING([TotalNullBytes], [n], 1) / [BitValue]) % 2))
							END) --as NullBitMap     
						FROM N4 AS Nums --sequence from 1 to 256
						--Use this technique to repeate the row till the no of bytes of the row
						INNER JOIN RowData AS rd ON [n] <= [TotalNullBitmapSize]
						CROSS JOIN #BitTable 
						WHERE rd.[RowLogContents] = D.[RowLogContents] 
						ORDER BY [RowLogContents], [n] ASC 
						FOR XML PATH('')
					),1,1,''
				),',',''))
				,[VarNumOfCols]
				,[VarColsOffsetArray]
				,[VarLengthDataStart]
				,[SlotId]
			FROM RowData D


			IF NOT EXISTS (SELECT 1 FROM #DeletedRows) 
			BEGIN
				RAISERROR (N'There are no tran log records for this table', 16, 1);
				--RETURN
			END

			-- select * from #DeletedRows

 

			-- Get each column details
			DROP TABLE IF EXISTS #ColumnData
			SELECT 
				dr.[RowId],
				dr.[RowLogContents],
				c.Name,
				t.name AS [DataTypeName],
				cols.leaf_offset,
				CASE 
					WHEN cols.leaf_offset > 0 
					THEN (SELECT TOP 1 ISNULL(SUM(CASE 
											WHEN C.leaf_offset > 1
											THEN C.max_length 
											ELSE 0 
										  END),0) 
						 FROM sys.system_internals_partition_columns C 
						 WHERE cols.partition_id = C.partition_id And C.leaf_null_bit < cols.leaf_null_bit) + 5
					ELSE 0
				END AS [FixColumnValueStartPosition],
				CASE 
					WHEN cols.leaf_offset > 0 
					THEN 0
					ELSE cols.leaf_offset*-1
				END AS [VarNextColOrder],
				CASE 
					WHEN cols.leaf_offset = -1  --first var column
					THEN [VarLengthDataStart]
					ELSE dbo.UDF_GetIntFromNtoMBytes([VarColsOffsetArray], 2 * ((cols.leaf_offset*-1) - 1) - 1, 2)
				END AS [VarColumnValueStartPosition],
				dbo.UDF_GetIntFromNtoMBytes([VarColsOffsetArray], (2 * cols.leaf_offset*-1) - 1, 2) AS [VarColumnValueEndPosition],
				CASE 
					WHEN cols.leaf_offset > 0 
					THEN c.max_length 
					ELSE 0
				END AS [ColumnLength],
				cols.leaf_null_bit AS [NullBit],
				cols.System_Type_Id as [SystemTypeId],
				cols.leaf_bit_position AS [BitPos],
				ISNULL(c.precision, cols.precision) AS [Precision],
				ISNULL(c.scale, cols.scale) AS [Scale],
				SUBSTRING(dr.TotalNullBitMap, cols.leaf_null_bit, 1) AS [IsNull],
				dr.[SlotId]
			INTO #ColumnData
			FROM #DeletedRows dr
			INNER JOIN sys.system_internals_partition_columns cols --!undocumented!
				ON dr.PartitionId = cols.partition_id 
			LEFT JOIN sys.columns c 
				ON dr.ObjectId = c.object_id AND c.column_id = cols.partition_column_id
			LEFT JOIN sys.types t
				ON c.system_type_id = t.system_type_Id AND c.user_type_id = t.user_type_id

			-- select * from #ColumnData --where VarColumnValueEndPosition > 0 order by [VarColumnValueStartPosition]



			--DROP TABLE IF EXISTS #ColumnDataHexValue 
			INSERT INTO #ColumnDataHexValue
			--This part is for fixed data columns
			SELECT
				cols.[RowId],
				cols.[RowLogContents],
				cols.[Name],
				cols.[DataTypeName],
				cols.[NullBit],
				cols.[SystemTypeId],
				cols.[BitPos],
				cols.[Precision],  --for NUMERIC
				cols.[Scale], --for NUMERIC
				cols.[IsNull],
				cols.[FixColumnValueStartPosition] AS [ColumnValueStartPosition],
				cols.[ColumnLength],
				(CASE 
					WHEN cols.[IsNull] = 0
					THEN SUBSTRING([RowLogContents], [FixColumnValueStartPosition], cols.[ColumnLength])  
				  END) AS [HexValue],
				cols.[SlotId],
				0 as [Update]
			FROM #ColumnData cols
			WHERE cols.[FixColumnValueStartPosition] > 0

			UNION ALL

			--This part is for variable data columns
			SELECT
				cols.[RowId],
				cols.[RowLogContents],
				cols.[Name],
				cols.[DataTypeName],
				cols.[NullBit],
				cols.[SystemTypeId],
				cols.[BitPos],
				cols.[Precision],
				cols.[Scale],
				cols.[IsNull],
				(CASE 
					WHEN cols.[IsNull] = 0 
					THEN (CASE 
							WHEN [VarColumnValueEndPosition] > POWER(2, 15)
							THEN [VarColumnValueEndPosition] - POWER(2, 15)  --32768
							ELSE [VarColumnValueEndPosition]
					END)
				END) AS [ColumnValueStartPosition],

				(CASE 
					WHEN cols.[IsNull] = 0  
					THEN (CASE
							WHEN [VarColumnValueEndPosition] > POWER(2, 15) 
							THEN (CASE WHEN cols.DataTypeName In ('image','text','ntext') THEN 16 ELSE 24 END)
 
							WHEN [VarColumnValueEndPosition] < POWER(2, 15) AND [VarColumnValueStartPosition] < POWER(2, 15)
							THEN [VarColumnValueEndPosition] - [VarColumnValueStartPosition]
 
							WHEN [VarColumnValueEndPosition] < POWER(2, 15) AND [VarColumnValueStartPosition] > POWER(2, 15)
							THEN POWER(2, 15) + [VarColumnValueEndPosition] - [VarColumnValueStartPosition]
						  END)
				END) AS [ColumnLength],

				(CASE 
					WHEN cols.[IsNull] = 0 
					THEN SUBSTRING ([RowLogContents],

					--from = [ColumnValueStartPosition]-[ColumnLength]
					(CASE 
						WHEN [VarColumnValueEndPosition] > POWER(2, 15)
						THEN [VarColumnValueEndPosition] - POWER(2, 15)
						ELSE [VarColumnValueEndPosition]
					END)
					- 
					(CASE 
						WHEN [VarColumnValueEndPosition] > POWER(2, 15)
						THEN (CASE WHEN cols.DataTypeName In ('image','text','ntext') THEN 16 ELSE 24 END) 

						WHEN [VarColumnValueEndPosition] < POWER(2, 15) AND [VarColumnValueStartPosition] < POWER(2, 15)
						THEN [VarColumnValueEndPosition] - [VarColumnValueStartPosition]
 
						WHEN [VarColumnValueEndPosition] < POWER(2, 15) AND [VarColumnValueStartPosition] > POWER(2, 15)
						THEN POWER(2, 15) + [VarColumnValueEndPosition] - [VarColumnValueStartPosition]
					END)
					+ 1, 
		
					--length
					(CASE 
						WHEN [VarColumnValueEndPosition] > POWER(2, 15) 
						THEN (CASE WHEN cols.DataTypeName In ('image','text','ntext') THEN 16 ELSE 24 END) 
				
						WHEN [VarColumnValueEndPosition] < POWER(2, 15) And [VarColumnValueStartPosition] < POWER(2, 15)
						THEN ABS([VarColumnValueEndPosition] - [VarColumnValueStartPosition])
				
						WHEN [VarColumnValueEndPosition] < POWER(2, 15) And [VarColumnValueStartPosition] > POWER(2, 15)
						THEN POWER(2, 15) + [VarColumnValueEndPosition] - [VarColumnValueStartPosition]
					END)
					)
				 END) AS [HexValue]
				,[SlotId]
				,0 as [Update]
			FROM #ColumnData cols
			WHERE cols.[VarColumnValueEndPosition] > 0
			ORDER BY [NullBit]


			-- select * from #ColumnDataHexValue order by RowId, Name



			-- Update HexValue for Bit datatype 
			DECLARE @BitColumnByte AS INT
			SELECT @BitColumnByte = CONVERT(INT, ceiling(COUNT(*)/8.0)) FROM #ColumnDataHexValue WHERE [DataTypeName] = 'bit'
 
 
			;WITH N1 (n) AS (SELECT 1 UNION ALL SELECT 1),
			N2 (n) AS (SELECT 1 FROM N1 AS X, N1 AS Y),
			N3 (n) AS (SELECT 1 FROM N2 AS X, N2 AS Y),
			N4 (n) AS (SELECT ROW_NUMBER() OVER(ORDER BY X.n)
					   FROM N3 AS X, N3 AS Y)
			,CTE As (
			SELECT 
				RowLogContents 
				,NullBit
				,BitMap = CONVERT(VARBINARY(1),CONVERT(INT,SUBSTRING((REPLACE(STUFF((
					SELECT ',' +
						CASE 
							WHEN [Id]=0 
							THEN CONVERT(NVARCHAR(1),(SUBSTRING([HexValue], [n], 1) % 2))  
							ELSE CONVERT(NVARCHAR(1),((SUBSTRING([HexValue], [n], 1) / [BitValue]) % 2)) 
						END --as NullBitMap
					FROM N4 AS Nums
					INNER JOIN #ColumnDataHexValue AS c 
						ON n <= @BitColumnByte AND [DataTypeName] = 'bit' AND [BitPos] = 0
					CROSS JOIN #BitTable 
					WHERE c.[RowLogContents] = d.[RowLogContents] 
					ORDER BY [RowLogContents], [n] ASC FOR XML PATH('')),1,1,''),',','')), [BitPos] + 1, 1)))
			FROM #ColumnDataHexValue d 
			WHERE [DataTypeName] = 'bit'
			)
 
			UPDATE A 
			SET HexValue = b.BitMap
			FROM #ColumnDataHexValue a
			INNER JOIN CTE b 
				ON a.RowLogContents = b.RowLogContents
			AND a.NullBit = b.NullBit

		END

		IF @IsDebugMode = 1
			SELECT * FROM #ColumnDataHexValue ORDER BY ColumnValueStartPosition


		/**********Check for IN_ROW_DATA. End************/

		--TO DO - test do we really need sql_variant, char, nchar in BLOB section?

		/**********Check for BLOB DATA TYPES. Start************/
		/*
		IF EXISTS(
		SELECT 1 FROM #ColumnDataHexValue
		WHERE SystemTypeId IN (34,35,98,99,165,167,175,231,239,241)
		) AND @HasBlobData = 1
		BEGIN
			/*
			SELECT system_type_id, name
			FROM sys.types
			WHERE system_type_id = user_type_id
				AND system_type_id In (34,35,98,99,165,167,175,231,239,241)

			select * from #ColumnDataHexValue
			where SystemTypeId In (34,35,98,99,165,167,175,231,239,241)
			AND Name in ('Col_image','Col_text','Col_varchar_sql_variant','Col_varbinary_sql_variant',
				'Col_ntext','Col_varbinary','Col_varchar','Col_nvarchar','Col_xml')

			select * FROM #FinalData
			where SystemTypeId In (34,35,98,99,165,167,175,231,239,241)
			AND FieldName in ('Col_image','Col_text','Col_varchar_sql_variant','Col_varbinary_sql_variant',
				'Col_ntext','Col_varbinary','Col_varchar','Col_nvarchar','Col_xml')

			image         - 34	
			text          - 35
			sql_variant   - 98 - really BLOB?
			ntext         - 99
			varbinary(max)- 165
			varchar(max)  - 167
			char          - 175 - really BLOB?
			nvarchar(max) - 231
			nchar         - 239 - really BLOB?
			xml           - 241
			*/

			/*
			-- Get StartLSN in VARCHAR - first parameter to sys.fn_dblog - for fast search
			DECLARE @StartLSN NVARCHAR(25) = (SELECT TOP 1 [Current LSN] FROM #TransactionWithDelete ORDER BY CAST([Begin Time] as DATETIME) DESC)
	
			DECLARE @N1 BIGINT = CONVERT(varbinary,SUBSTRING(@StartLSN, 1, 8),2),
					@N2 BIGINT = CONVERT(varbinary,SUBSTRING(@StartLSN, 10, 8),2),
					@N3 BIGINT = CONVERT(varbinary,SUBSTRING(@StartLSN, 19, 4),2)

			SELECT @StartLSN = CAST(@N1 AS VARCHAR) + ':' + CAST(@N2 AS VARCHAR) + ':' + CAST(@N3 AS VARCHAR)
			*/

			/*
			We need to filter LOP_MODIFY_ROW, LOP_MODIFY_COLUMNS from tran log for deleted records of BLOB data type
			LCX_PFS does mean that the PFS-Page will be updated. 
			Heaps and BLOBS use PFS quite frequently when existing data will be deleted
			*/
			DROP TABLE IF EXISTS #DeallocateSpaceLOB	
			SELECT 
				f.[DeallocateSpaceLOBConsolidatedPageID] AS [ConsolidatedPageID]
				,f.[SlotId]
				,f.[AllocUnitId]
				,f.[TypeDesc]
				,CAST(NULL as VARBINARY(8000)) AS [RowLogHexValue]
				,NULL AS [LinkId]
				,f.[Context]
			INTO #DeallocateSpaceLOB
			FROM #MyTransaction f
			WHERE 1=1
				AND f.[Context] IN ('LCX_PFS') 
				AND f.[Operation] IN ('LOP_MODIFY_ROW')  
				AND f.[TypeDesc] IN ('LOB_DATA', 'ROW_OVERFLOW_DATA')
				AND f.[DeallocateSpaceLOBConsolidatedPageID] IS NOT NULL

			-- select * from #DeallocateSpaceLOB order by [ConsolidatedPageID]

			/*
			 m_type = 3 
			 A text page that holds small chunks of LOB values plus internal parts of text tree. 
			 These can be shared between LOB values in the same partition of an index or heap
			 https://www.sqlskills.com/blogs/paul/inside-the-storage-engine-anatomy-of-a-page/
			*/
			DROP TABLE IF EXISTS #TextMixLOB
			SELECT 
				f.[TextMixLOBConsolidatedPageID] AS [ConsolidatedPageID]
				,f.[SlotId]
				,f.[AllocUnitId] 
				,f.[TypeDesc]
				,f.[RowLogHexValue] 
				,f.[LinkId]
				,f.[Context]
			INTO #TextMixLOB
			FROM #MyTransaction f
			WHERE 1=1
				AND f.[Context] IN ('LCX_TEXT_MIX') 
				AND f.[Operation] IN ('LOP_DELETE_ROWS') 
				AND f.[TypeDesc] IN ('LOB_DATA', 'ROW_OVERFLOW_DATA')

			-- select * from #TextMixLOB


 
			DROP TABLE IF EXISTS #BasedPageData
			CREATE TABLE #BasedPageData 
			(
				[ParentObject]  SYSNAME,
				[Object]		SYSNAME,
				[Field]			SYSNAME,
				[Value]			SYSNAME
			)
 
 			DROP TABLE IF EXISTS #PageData
			CREATE TABLE #PageData
			(
				[ConsolidatedPageId] SYSNAME,
				[FileId]			 INT,
				[PageId]			 INT,
				[AllocUnitId]		 BIGINT,
				[SlotId]			 INT,
				[PreValue]           SYSNAME,
				[Value]				 SYSNAME,
			)
 
			DROP TABLE IF EXISTS #ModifiedRawData
			CREATE TABLE #ModifiedRawData 
			(
			  [Id]						INT IDENTITY(1,1),
			  [ConsolidatedPageId]		VARCHAR(MAX),
			  [FileId]					INT,
			  [PageId]					INT,
			  [SlotId]					INT,
			  [AllocUnitId]				BIGINT,
			  [RowLogLengthInt]			INT,
			  [RowLogHexValue]			VARBINARY(Max), --concatenated hex value in varbinary format
			  [LinkId]					INT DEFAULT (0),
			  [Update]					INT
			)

			DECLARE 
				@FileId INT, 
				@PageId INT, 
				@ConsolidatedPageId VARCHAR(MAX),
				@SlotId INT,
				@LinkId INT,
				@AllocUnitId BIGINT,
				--@DBName NVARCHAR(MAX) = 'AdventureWorks',
				@RowLogHexValue VARBINARY(8000)

			DECLARE Page_Data_Cursor CURSOR FOR

				SELECT 
					[ConsolidatedPageID]
					,[SlotId]
					,[AllocUnitId]
					,[RowLogHexValue]
					,[LinkId]
				FROM #DeallocateSpaceLOB  
				UNION ALL
				SELECT 
					[ConsolidatedPageID]
					,[SlotId]
					,[AllocUnitId]
					,[RowLogHexValue]
					,[LinkId]
				FROM #TextMixLOB
                         
				OPEN Page_Data_Cursor
				FETCH NEXT FROM Page_Data_Cursor INTO @ConsolidatedPageId, @SlotId, @AllocUnitId, @RowLogHexValue, @LinkId
 
				WHILE @@FETCH_STATUS = 0
				BEGIN
					DECLARE @PageIdHex AS VARCHAR(Max)

					-- Seperate FileID from PageID
					SET @FileId = SUBSTRING(@ConsolidatedPageID,0,CHARINDEX(':',@ConsolidatedPageID)) 
         
					--Seperate the PageID in Hex
					SET @PageIdHex ='0x'+ SUBSTRING(@ConsolidatedPageID,CHARINDEX(':',@ConsolidatedPageID)+1,Len(@ConsolidatedPageID)) 
			
					-- Convert PageID from hex to integer
					SELECT @PageId = Convert(INT,cast('' AS XML).value('xs:hexBinary(substring(sql:variable("@PageIdHex"),sql:column("t.pos")) )', 'varbinary(max)')) 
					FROM (SELECT CASE SUBSTRING(@PageIdHex, 1, 2) WHEN '0x' THEN 3 ELSE 0 END) AS t(pos) 
             

					IF @LinkId IS NULL --#DeallocateSpaceLOB	 
					BEGIN
						DELETE #BasedPageData

						INSERT INTO #BasedPageData 
						EXEC( 'DBCC PAGE(' + @DBName + ', ' + @FileId + ', ' + @PageId + ', 1) with tableresults,no_infomsgs;'); 

						INSERT INTO #PageData 
						SELECT 
							@ConsolidatedPageID, @FileId, @PageId, @AllocUnitID
							,Substring([ParentObject],CHARINDEX('Slot', [ParentObject])+4, (CHARINDEX('Offset', [ParentObject])-(CHARINDEX('Slot', [ParentObject])+4))-2 ) as [SlotId]
							,LEFT([Value],CHARINDEX(':',[Value])-1) as [PreValue]
							,[Value]
						FROM #BasedPageData
						WHERE [Object] Like 'Memory Dump%'
					END

					ELSE IF @LinkId > 0 --#TextMixLOB
					BEGIN
						INSERT INTO #ModifiedRawData 
						([ConsolidatedPageID], [FileId], [PageId], [SlotId], [AllocUnitId], 
						[RowLogLengthInt], [RowLogHexValue], 
						[LinkId], [Update]
						)
						SELECT 
							@ConsolidatedPageId, @FileId, @PageId, @Slotid, @AllocUnitID, 
							CONVERT(INT,CONVERT(VARBINARY,REVERSE(SUBSTRING(@RowLogHexValue,11,2)))) as [RowLogLengthInt], 
							@RowLogHexValue, 
							@LinkId, 0 as [Update]
					END    
					FETCH NEXT FROM Page_Data_Cursor INTO @ConsolidatedPageId, @SlotId, @AllocUnitId, @RowLogHexValue, @LinkId
				END
     
			CLOSE Page_Data_Cursor
			DEALLOCATE Page_Data_Cursor


			/*
			select * FROM #ModifiedRawData 

			select * from #PageData where PageId = 37753

			select * from #BasedPageData 
			*/

 
			--#DeallocateSpaceLOB
			--The data is in multiple rows for the (PageId, SlotId), so we need to convert it into one row as a single hex value.
			--This hex values [RowLogHexValueString] and [RowLogLengthHexString] are in string format
			DROP TABLE IF EXISTS #PageDataHexValue
			SELECT 
				[ConsolidatedPageId],[FileId],[PageId],[SlotId],[AllocUnitId]
				,SUBSTRING((
					SELECT '0' +
					REPLACE(STUFF((
					SELECT 
						SUBSTRING([Value],CHARINDEX(':',[Value])+4, 44)
					FROM #PageData C  
					WHERE C.[ConsolidatedPageID] = B.[ConsolidatedPageID] 
						And C.SlotId = B.SlotId
					Order By '0x'+ [PreValue]
					FOR XML PATH('') ),1,1,'') ,' ','')
					),1,20000) AS [RowLogHexValueString]
				,SUBSTRING((
					SELECT '0x' +
					REPLACE(STUFF((
					SELECT 
						SUBSTRING([Value],CHARINDEX(':',[Value])+4, 44)
					FROM #PageData C  
					WHERE C.[ConsolidatedPageID] = B.[ConsolidatedPageID]
						And C.SlotId = B.SlotId
					Order By '0x'+ [PreValue]
					FOR XML PATH('') ),1,1,'') ,' ','')
					),6,4) AS [RowLogLengthHexString] -- Bytes 2 and 3 are the offset of the null bitmap in the record
			INTO #PageDataHexValue
			FROM #PageData B
			GROUP BY [ConsolidatedPageID],[FileId],[PageId],[SlotId],[AllocUnitId]

			-- SELECT * FROM #PageDataHexValue

			-- Convert the binary data to a string of hexadecimal characters
			INSERT INTO #ModifiedRawData 
			([ConsolidatedPageId], [FileId], [PageId], [SlotId], [AllocUnitId], [RowLogHexValue], [RowLogLengthInt])
			SELECT 
				[ConsolidatedPageId], [FileId], [PageId], [SlotId], [AllocUnitId], 
				[RowLogHexValue] = CAST('' AS XML).value('xs:hexBinary(substring(sql:column("[RowLogHexValueString]"),0))', 'varbinary(Max)'),  
				[RowLogLengthInt] = CONVERT(VARBINARY(8000),REVERSE(CAST('' AS XML).value('xs:hexBinary(substring(sql:column("[RowLogLengthHexString]"),0))', 'varbinary(Max)')))
			FROM #PageDataHexValue
			ORDER BY [ConsolidatedPageID],[FileId],[PageId],[SlotId],[AllocUnitId]

			PRINT CONCAT('4. #ModifiedRawData is ready', CONVERT(TIME, GETDATE()))
			/*


			SELECT 
				*,
				--Convert(int,Convert(Varbinary(Max),Reverse(Substring(B.[RowLogHexValue],19+14,2)))) as FileIdA,
				--Convert(int,Convert(Varbinary(Max),Reverse(Substring(B.[RowLogHexValue],15+14,2)))) as PageIdA,
				--Convert(int,Convert(Varbinary(Max),Reverse(Substring(B.[RowLogHexValue],31+14,2)))) as FileIdC,
				--Convert(int,Convert(Varbinary(Max),Reverse(Substring(B.[RowLogHexValue],27+14,2)))) as PageIdC,
				CASE WHEN [RowLogLengthInt] >= 8000 THEN SUBSTRING([RowLogHexValue],[RowLogLengthInt]-8000+1,[RowLogLengthInt]) END as Above8000,
				CASE WHEN [RowLogLengthInt] < 8000 THEN SUBSTRING([RowLogHexValue],15+6,Convert(int,Convert(varbinary(max),REVERSE(SUBSTRING([RowLogHexValue],15,6))))) END as Below8000
			FROM #ModifiedRawData B
			WHERE [LinkId] = 0
			*/

 
			UPDATE B 
				SET [RowLogHexValue] = 
				CASE 
					WHEN A.[RowLogHexValue] IS NOT NULL AND C.[RowLogHexValue] IS NOT NULL THEN  A.[RowLogHexValue]+C.[RowLogHexValue] 
					WHEN A.[RowLogHexValue] IS NULL AND C.[RowLogHexValue] IS NOT NULL THEN  C.[RowLogHexValue]
					WHEN A.[RowLogHexValue] IS NOT NULL AND C.[RowLogHexValue] IS NULL THEN  A.[RowLogHexValue]  
				END
				,B.[Update] = ISNULL(B.[Update],0)+1
			FROM #ModifiedRawData B
			LEFT JOIN #ModifiedRawData A 
				ON A.[FileId] = Convert(int,Convert(Varbinary(Max),Reverse(Substring(B.[RowLogHexValue],19+14,2))))  
				AND A.[PageId] = Convert(int,Convert(Varbinary(Max),Reverse(Substring(B.[RowLogHexValue],15+14,2))))
				AND A.[LinkId] = B.[LinkId] 
			LEFT JOIN #ModifiedRawData C 
				ON C.[FileId] = Convert(int,Convert(Varbinary(Max),Reverse(Substring(B.[RowLogHexValue],31+14,2))))
				AND C.[PageId] = Convert(int,Convert(Varbinary(Max),Reverse(Substring(B.[RowLogHexValue],27+14,2))))
				AND C.[LinkId] = B.[LinkId] 
			WHERE A.[RowLogHexValue] IS NOT NULL OR C.[RowLogHexValue] IS NOT NULL
 
			--LinkId > 0 -#TextMixLOB
			UPDATE B 
				SET B.[RowLogHexValue] =
				CASE 
					WHEN A.[RowLogHexValue] IS NOT NULL AND C.[RowLogHexValue] IS NOT NULL THEN  A.[RowLogHexValue]+C.[RowLogHexValue] 
					WHEN A.[RowLogHexValue] IS NULL AND C.[RowLogHexValue] IS NOT NULL THEN  C.[RowLogHexValue]
					WHEN A.[RowLogHexValue] IS NOT NULL AND C.[RowLogHexValue] IS NULL THEN  A.[RowLogHexValue]  
				END
				,B.[Update]=ISNULL(B.[Update],0)+1
			FROM #ModifiedRawData B
			LEFT JOIN #ModifiedRawData A 
				On A.[PageId] = Convert(int,Convert(Varbinary(Max),Reverse(Substring(B.[RowLogHexValue],15+14,2))))
				And A.[FileId] = Convert(int,Convert(Varbinary(Max),Reverse(Substring(B.[RowLogHexValue],19+14,2)))) 
				And A.[LinkId] <> B.[LinkId] 
				And B.[Update] = 0
			LEFT JOIN #ModifiedRawData C 
				On C.[PageId] = Convert(int,Convert(Varbinary(Max),Reverse(Substring(B.[RowLogHexValue],27+14,2))))
				And C.[FileId] = Convert(int,Convert(Varbinary(Max),Reverse(Substring(B.[RowLogHexValue],31+14,2))))
				And C.[LinkId] <> B.[LinkId] 
				And B.[Update] = 0
			WHERE A.[RowLogHexValue] IS NOT NULL OR C.[RowLogHexValue] IS NOT NULL
 
			UPDATE #ModifiedRawData  
				SET [RowLogHexValue] = 
				CASE 
					WHEN [RowLogLengthInt] >= 8000 
					THEN SUBSTRING([RowLogHexValue],[RowLogLengthInt]-8000+1,[RowLogLengthInt])
					WHEN [RowLogLengthInt] < 8000 
					THEN SUBSTRING([RowLogHexValue],15+6,Convert(int,Convert(varbinary(max),REVERSE(SUBSTRING([RowLogHexValue],15,6)))))
				END
			FROM #ModifiedRawData 
			WHERE [LinkId] = 0

			/*
			select * FROM #ModifiedRawData

			select *
			from #ColumnDataHexValue A
			WHERE SystemTypeId IN (34,35,98,99,165,167,175,231,239,241) 
			*/


			--Final updates of HexValue in #ColumnDataHexValue
			UPDATE A
				SET 
					A.ColumnLength = B.RowLogLengthInt
					,A.HexValue = B.[RowLogHexValue] 
					,A.[Update]=A.[Update]+1
			FROM #ColumnDataHexValue A
			INNER JOIN #ModifiedRawData B 
				ON Convert(int,Convert(Varbinary(Max),Reverse(Substring(A.HexValue,17,4)))) = B.[PageId]
				AND Convert(int,Substring(A.HexValue,9,2)) = B.[LinkId] 
			WHERE SystemTypeId IN (98,99,165,167,175,231,239,241) 
				AND B.[LinkId] <> 0 
 
			--varchar, varbinary,nvarchar, sql_variant, xml
			UPDATE A 
				SET 
					A.ColumnLength = 
					CASE 
						WHEN B.[RowLogHexValue] IS NOT NULL AND C.[RowLogHexValue] IS NOT NULL THEN  B.RowLogLengthInt+C.RowLogLengthInt 
						WHEN B.[RowLogHexValue] IS NULL AND C.[RowLogHexValue] IS NOT NULL THEN  C.RowLogLengthInt
						WHEN B.[RowLogHexValue] IS NOT NULL AND C.[RowLogHexValue] IS NULL THEN  B.RowLogLengthInt  
					END,
					A.HexValue =
					CASE 
						WHEN B.[RowLogHexValue] IS NOT NULL AND C.[RowLogHexValue] IS NOT NULL THEN  B.[RowLogHexValue]+C.[RowLogHexValue] 
						WHEN B.[RowLogHexValue] IS NULL AND C.[RowLogHexValue] IS NOT NULL THEN  C.[RowLogHexValue]
						WHEN B.[RowLogHexValue] IS NOT NULL AND C.[RowLogHexValue] IS NULL THEN  B.[RowLogHexValue]  
					END
					,A.[Update]=A.[Update]+1
			FROM #ColumnDataHexValue A
			LEFT JOIN #ModifiedRawData B 
				ON Convert(int,Convert(Varbinary(Max),Reverse(Substring(A.HexValue,5,4)))) = B.[PageId]
				AND B.[LinkId] = 0 
			LEFT JOIN #ModifiedRawData C 
				ON Convert(int,Convert(Varbinary(Max),Reverse(Substring(A.HexValue,17,4)))) = C.[PageId]  
				AND C.[LinkId] = 0 
			WHERE SystemTypeId IN (98,99,165,167,175,231,239,241) 
				AND (B.[RowLogHexValue] IS NOT NULL OR C.[RowLogHexValue] IS NOT NULL)
 
			--image, text, ntext
			UPDATE A 
				SET 
					A.ColumnLength = B.RowLogLengthInt
					,A.HexValue = B.[RowLogHexValue]  
					,A.[Update]=A.[Update]+1
			FROM #ColumnDataHexValue A
			INNER JOIN #ModifiedRawData B 
				ON Convert(int,Convert(Varbinary(Max),Reverse(Substring(A.HexValue,9,4)))) = B.[PageId]
				And Convert(int,Substring(HexValue,3,2)) = B.[LinkId]
			WHERE SystemTypeId IN (34,35,99) 
				AND B.[LinkId] <> 0 
    
			--image, text, ntext
			UPDATE A 
				SET 
					A.ColumnLength = B.RowLogLengthInt
					,A.HexValue = B.[RowLogHexValue] 
					,A.[Update]=A.[Update]+10
			FROM #ColumnDataHexValue A
			INNER JOIN #ModifiedRawData B 
				ON Convert(int,Convert(Varbinary(Max),Reverse(Substring(A.HexValue,9,4)))) = B.[PageId]
			WHERE SystemTypeId IN (34,35,99) 
				AND B.[LinkId] = 0
 
			--image, text, ntext
			UPDATE A 
				SET 
					A.ColumnLength = B.RowLogLengthInt
					,A.HexValue = B.[RowLogHexValue]
					,A.[Update]=A.[Update]+1
			FROM #ColumnDataHexValue A
			INNER JOIN #ModifiedRawData B 
				ON Convert(int,Convert(Varbinary(Max),Reverse(Substring(HexValue,15,4)))) = B.[PageId]
			WHERE SystemTypeId IN (34,35,99) 
				AND B.[LinkId] = 0
 
			--xml
			UPDATE #ColumnDataHexValue 
				SET 
					HexValue= 0xFFFE + HexValue 
					,[Update]=[Update]+1
			WHERE SystemTypeId = 241


		/*
			select 
				*
			from #ColumnDataHexValue A
			WHERE SystemTypeId IN (34,35,98,99,165,167,175,231,239,241) 
		*/

		END

		*/
		/**********Check for BLOB DATA TYPES. End************/
	END
	/************************ Loop by rows. End ***********************/



	--Final values
	DROP TABLE IF EXISTS #FinalData
	CREATE TABLE #FinalData
	(
		[RowId]			 INT,
		[SystemTypeId]   INT,
		[FieldName]		 VARCHAR(MAX),
		[FieldValue]	 NVARCHAR(MAX),
		[FieldLength]	 INT,
		[HexValue]       VARBINARY(max),
		[RowLogContents] VARBINARY(8000)
	)
	
	--Convert the data with respect to its datatype defined as SystemTypeId 
	-- Varbinary_Sqlvariant is 8002 instead of 8000
	-- Col_ntext is 3997 instead of 4000
	INSERT INTO #FinalData
	SELECT 
		RowId,
		SystemTypeId,
		NAME,
		CASE
		 WHEN SystemTypeId IN (231, 239) THEN  LTRIM(RTRIM(CONVERT(NVARCHAR(max),HexValue)))  --NVARCHAR ,NCHAR
		 WHEN SystemTypeId IN (167,175) THEN  LTRIM(RTRIM(CONVERT(VARCHAR(max),HexValue)))  --VARCHAR,CHAR
		 WHEN SystemTypeId IN (35) THEN  LTRIM(RTRIM(CONVERT(VARCHAR(max),HexValue))) --Text
		 WHEN SystemTypeId IN (99) THEN  LTRIM(RTRIM(CONVERT(NVARCHAR(max),HexValue))) --nText 
		 WHEN SystemTypeId = 48 THEN CONVERT(VARCHAR(MAX), CONVERT(TINYINT, CONVERT(BINARY(1), REVERSE (HexValue)))) --TINY INTEGER
		 WHEN SystemTypeId = 52 THEN CONVERT(VARCHAR(MAX), CONVERT(SMALLINT, CONVERT(BINARY(2), REVERSE (HexValue)))) --SMALL INTEGER
		 WHEN SystemTypeId = 56 THEN CONVERT(VARCHAR(MAX), CONVERT(INT, CONVERT(BINARY(4), REVERSE(HexValue)))) -- INTEGER
		 WHEN SystemTypeId = 127 THEN CONVERT(VARCHAR(MAX), CONVERT(BIGINT, CONVERT(BINARY(8), REVERSE(HexValue))))-- BIG INTEGER
		 WHEN SystemTypeId = 61 Then CONVERT(VARCHAR(MAX),CONVERT(DATETIME,CONVERT(VARBINARY(8000),REVERSE (HexValue))),100) --DATETIME
		 WHEN SystemTypeId = 58 Then CONVERT(VARCHAR(MAX),CONVERT(SMALLDATETIME,CONVERT(VARBINARY(8000),REVERSE(HexValue))),100) --SMALL DATETIME
		 WHEN SystemTypeId = 108 THEN CONVERT(VARCHAR(MAX),CONVERT(NUMERIC(38,20), CONVERT(VARBINARY,CONVERT(VARBINARY(1),Precision)+CONVERT(VARBINARY(1),Scale))+CONVERT(VARBINARY(1),0) + HexValue)) --- NUMERIC
		 WHEN SystemTypeId = 106 THEN CONVERT(VARCHAR(MAX), CONVERT(DECIMAL(38,20), CONVERT(VARBINARY,Convert(VARBINARY(1),Precision)+CONVERT(VARBINARY(1),Scale))+CONVERT(VARBINARY(1),0) + HexValue)) --- DECIMAL
		 WHEN SystemTypeId IN (60,122) THEN CONVERT(VARCHAR(MAX),Convert(MONEY,Convert(VARBINARY(8000),Reverse(HexValue))),2) --MONEY,SMALLMONEY
		 WHEN SystemTypeId = 104 THEN CONVERT(VARCHAR(MAX),CONVERT (BIT,CONVERT(BINARY(1), HexValue)%2))  -- BIT
		 WHEN SystemTypeId = 62 THEN  RTRIM(LTRIM(STR(CONVERT(FLOAT,SIGN(CAST(CONVERT(VARBINARY(8000),Reverse(HexValue)) AS BIGINT)) * (1.0 + (CAST(CONVERT(VARBINARY(8000),Reverse(HexValue)) AS BIGINT) & 0x000FFFFFFFFFFFFF) * POWER(CAST(2 AS FLOAT), -52)) * POWER(CAST(2 AS FLOAT),((CAST(CONVERT(VARBINARY(8000),Reverse(HexValue)) AS BIGINT) & 0x7ff0000000000000) / EXP(52 * LOG(2))-1023))),53,LEN(HexValue)))) --- FLOAT
		 When SystemTypeId = 59 THEN  Left(LTRIM(STR(CAST(SIGN(CAST(Convert(VARBINARY(8000),REVERSE(HexValue)) AS BIGINT))* (1.0 + (CAST(CONVERT(VARBINARY(8000),Reverse(HexValue)) AS BIGINT) & 0x007FFFFF) * POWER(CAST(2 AS Real), -23)) * POWER(CAST(2 AS Real),(((CAST(CONVERT(VARBINARY(8000),Reverse(HexValue)) AS INT) )& 0x7f800000)/ EXP(23 * LOG(2))-127))AS REAL),23,23)),8) --Real
		 WHEN SystemTypeId IN (165,173) THEN (CASE WHEN CHARINDEX(0x,cast('' AS XML).value('xs:hexBinary(sql:column("HexValue"))', 'VARBINARY(8000)')) = 0 THEN '0x' ELSE '' END) +cast('' AS XML).value('xs:hexBinary(sql:column("HexValue"))', 'varchar(max)') -- BINARY,VARBINARY
		 WHEN SystemTypeId = 34 THEN (CASE WHEN CHARINDEX(0x,cast('' AS XML).value('xs:hexBinary(sql:column("HexValue"))', 'VARBINARY(8000)')) = 0 THEN '0x' ELSE '' END) +cast('' AS XML).value('xs:hexBinary(sql:column("HexValue"))', 'varchar(max)')  --IMAGE
		 WHEN SystemTypeId = 36 THEN CONVERT(VARCHAR(MAX),CONVERT(UNIQUEIDENTIFIER,HexValue)) --UNIQUEIDENTIFIER
		 WHEN SystemTypeId = 231 THEN CONVERT(VARCHAR(MAX),CONVERT(sysname,HexValue)) --SYSNAME
		 WHEN SystemTypeId = 241 THEN CONVERT(VARCHAR(MAX),CONVERT(xml,HexValue)) --XML
		 WHEN SystemTypeId = 189 THEN (CASE WHEN CHARINDEX(0x,cast('' AS XML).value('xs:hexBinary(sql:column("HexValue"))', 'VARBINARY(8000)')) = 0 THEN '0x' ELSE '' END) +cast('' AS XML).value('xs:hexBinary(sql:column("HexValue"))', 'varchar(max)') --TIMESTAMP
		 WHEN SystemTypeId = 98 THEN --sql_variant
			CASE
				 WHEN CONVERT(INT,SUBSTRING(HexValue,1,1)) = 56 THEN CONVERT(VARCHAR(MAX), CONVERT(INT, CONVERT(BINARY(4), REVERSE(Substring(HexValue,3,Len(HexValue))))))  -- INTEGER
				 WHEN CONVERT(INT,SUBSTRING(HexValue,1,1)) = 108 THEN CONVERT(VARCHAR(MAX),CONVERT(numeric(38,20),CONVERT(VARBINARY(1),Substring(HexValue,3,1)) +CONVERT(VARBINARY(1),Substring(HexValue,4,1))+CONVERT(VARBINARY(1),0) + Substring(HexValue,5,Len(HexValue)))) --- NUMERIC
				 WHEN CONVERT(INT,SUBSTRING(HexValue,1,1)) = 67 THEN LTRIM(RTRIM(CONVERT(VARCHAR(max),HexValue))) --VARCHAR,CHAR
				 WHEN CONVERT(INT,SUBSTRING(HexValue,1,1)) = 36 THEN CONVERT(VARCHAR(MAX),CONVERT(UNIQUEIDENTIFIER,Substring((HexValue),3,20))) --UNIQUEIDENTIFIER
				 WHEN CONVERT(INT,SUBSTRING(HexValue,1,1)) = 61 THEN CONVERT(VARCHAR(MAX),CONVERT(DATETIME,CONVERT(VARBINARY(8000),REVERSE (Substring(HexValue,3,LEN(HexValue)) ))),100) --DATETIME
				 WHEN CONVERT(INT,SUBSTRING(HexValue,1,1)) = 68 THEN '0x'+ SUBSTRING((CASE WHEN CHARINDEX(0x,cast('' AS XML).value('xs:hexBinary(sql:column("HexValue"))', 'VARBINARY(8000)')) = 0 THEN '0x' ELSE '' END) +cast('' AS XML).value('xs:hexBinary(sql:column("HexValue"))', 'varchar(max)'),11,LEN(HexValue)) -- BINARY,VARBINARY
			END
		END AS FieldValue
		,ColumnLength
		,HexValue
		,RowLogContents
	FROM #ColumnDataHexValue 
	ORDER BY NullBit

	-- select * FROM #FinalData

	--Create the column name in the same order to do pivot table.
	DECLARE 
		@FieldNames VARCHAR(MAX),
		@MaxFieldNames VARCHAR(MAX)

	WITH base AS
    (
		SELECT DISTINCT FieldName --to avoid duplicates for N > 1 rows
		FROM #FinalData
	)
	SELECT 
		@FieldNames = STRING_AGG(FieldName, ','),
		@MaxFieldNames = STRING_AGG('MAX('+ FieldName +') as ' + FieldName, ',')
	FROM base
	SELECT @FieldNames, @MaxFieldNames

 
	--Finally did pivot table and get the data back in the same format.
 	DECLARE @SQL NVARCHAR(Max)
	SET @sql = 'SELECT RowId,' + @MaxFieldNames  + ' FROM #FinalData PIVOT (Min([FieldValue]) FOR FieldName IN (' + @FieldNames  + ')) AS pvt GROUP BY RowId'
	EXEC sp_executesql @sql

	/*
	Check errors:
	- Operand type clash: nvarchar(max) is incompatible with image
	- Cannot insert an explicit value into a timestamp column. 
		Use INSERT with a column list to exclude the timestamp column, or insert a DEFAULT into the timestamp column.

	DECLARE @SchemaTableName NVARCHAR(100) = 'dbo.Test_Table2'
	SET @sql = 'INSERT INTO ' + @SchemaTableName + ' SELECT ' + @MaxFieldNames  + ' FROM #FinalData PIVOT (Min([FieldValue]) FOR FieldName IN (' + @FieldNames  + ')) AS pvt GROUP BY RowId'
	EXEC sp_executesql @sql
	*/
 
END

