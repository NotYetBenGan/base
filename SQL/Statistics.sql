--Main detalization on incremental stats
DROP TABLE IF EXISTS ##Stats
SELECT
    p.OBJECT_ID,
    s.stats_id,
    s.name AS StatisticsName,
    s.is_incremental,
    s.auto_created,
    s.user_created,
    p.partition_number,
    CAST(COALESCE(prv_right.VALUE, 10000000) AS INT) AS PrtnId,
    p.ROW_COUNT
INTO ##Stats
FROM sys.dm_db_partition_stats p (NOLOCK)
INNER JOIN sys.indexes i (NOLOCK)
    ON i.OBJECT_ID = p.OBJECT_ID AND i.index_id = p.index_id
LEFT JOIN sys.partition_schemes ps (NOLOCK)
    ON ps.data_space_id = i.data_space_id
LEFT JOIN sys.partition_range_values prv_right (NOLOCK)
    ON prv_right.function_id = ps.function_id
    AND prv_right.boundary_id = p.partition_number
LEFT JOIN sys.stats s (NOLOCK)
    ON p.OBJECT_ID = s.object_id
WHERE 1=1
    AND OBJECTPROPERTY(p.OBJECT_ID, 'ISMSShipped') = 0
    AND p.used_page_count > 0
    AND p.index_id IN (0,1,5)
    AND p.ROW_COUNT > 0
    AND s.stats_id = 1
    AND p.ROW_COUNT > 0

SELECT
    'icon.' + OBJECT_NAME(p.OBJECT_ID) AS TableName,
    p.StatisticsName,
    --p.is_incremental,
    --p.auto_created,
    --p.user_created,
    --isp.stats_id,
    p.partition_number,
    p.PrtnId,
    isp.last_updated,
    p.ROW_COUNT,
    isp.rows AS Stats_ROW_COUNT,
    isp.rows_sampled,
    isp.steps,
    isp.unfiltered_rows, -- for filtered statistics
    isp.modification_counter
FROM ##Stats p
CROSS APPLY sys.dm_db_incremental_stats_properties(p.OBJECT_ID, p.stats_id) isp -- partition detalization
WHERE 1=1
    AND p.partition_number = isp.partition_number
    AND OBJECT_NAME(p.OBJECT_ID) IN ('TableName')
    AND p.PrtnId BETWEEN 835270 AND 835417
    --AND p.ROW_COUNT <> COALESCE(isp.rows,0)
ORDER BY TableName, p.PrtnId DESC

-- ============================================================
-- part2
-- ============================================================

SELECT
    t.name AS TableName,
    s.name AS StatisticsName,
    STATS_DATE(s.object_id, s.stats_id),
    s.is_incremental,
    s.auto_created,
    s.user_created,
    s.*
FROM sys.stats s
INNER JOIN sys.tables t 
    ON s.object_id = t.object_id
WHERE 1=1
    AND t.name IN ('TableName')
    AND t.schema_id = SCHEMA_ID('SchemaName')
    AND s.stats_id = 1
ORDER BY s.name

--Global histogram - always non empty, even for non-incremental dataset
SELECT
    SCHEMA_NAME(t.schema_id) AS SchemaName,
    t.name AS TableName,
    s.name AS StatisticsName,
    c.name as ColumnName,
    sc.stats_id,
    s.is_incremental,
    t.is_memory_optimized,
    STATS_DATE(s.object_id, s.stats_id) AS LastUpdated,
    h.*
FROM sys.tables t
INNER JOIN sys.stats s 
    ON t.object_id = s.object_id
LEFT JOIN sys.stats_columns sc
    ON sc.object_id = s.object_id
    AND sc.stats_id = s.stats_id
LEFT JOIN sys.columns c
    ON c.object_id = sc.object_id
    AND c.column_id = sc.column_id
OUTER APPLY sys.dm_db_stats_histogram(t.object_id, s.stats_id) h
WHERE 1=1
AND t.is_memory_optimized = 1
--AND t.name = 'TableName'
--AND s.stats_id = 1
ORDER BY h.stats_id, h.step_number DESC;


-- Threshold
SELECT
    p.partition_number,
    p.rows AS CurrentRows,
    sp.modification_counter, --Total number of modifications for the leading statistics column (the column on which the histogram is built) since the last time statistics were updated
    sp.last_updated,
    CASE
        WHEN p.rows < 500 THEN 500
        WHEN p.rows <= 25000 THEN CAST(p.rows * 0.20 AS INT)
        ELSE CAST(SQRT(1000.0 * p.rows) AS INT)
    END AS AutoUpdateThreshold,
    CASE
        WHEN sp.modification_counter >=
            CASE
                WHEN p.rows < 500 THEN 500
                WHEN p.rows <= 25000 THEN CAST(p.rows * 0.20 AS INT)
                ELSE CAST(SQRT(1000.0 * p.rows) AS INT)
            END
        THEN 'Should Update'
        ELSE 'Below Threshold'
    END AS UpdateStatus
FROM sys.partitions p
CROSS APPLY sys.dm_db_stats_properties(p.object_id, 1) sp
WHERE p.object_id = OBJECT_ID('SchemaName.TableName')
AND p.index_id <= 1
AND p.rows > 0
ORDER BY p.partition_number;



-- ============================================================
-- part3
-- ============================================================

select * from sys.dm_db_stats_properties(OBJECT_ID('SchemaName.TableName'),2)

select * from sys.dm_db_stats_properties_internal(OBJECT_ID('SchemaName.TableName'),1)

SELECT * FROM fn_my_permissions('sys.dm_db_stats_properties_internal','object');
SELECT * FROM fn_my_permissions('sys.databases','object');

use master
GRANT SELECT ON sys.dm_db_stats_properties_internal TO public

SELECT
    DB_NAME() AS DatabaseName,
    DATABASEPROPERTYEX(DB_NAME(), 'IsAutoUpdateStatistics') AS AutoUpdateStats,
    DATABASEPROPERTYEX(DB_NAME(), 'IsAutoUpdateStatisticsAsync') AS AutoUpdateStatsAsync;



-- ============================================================
-- part 4.
-- Owerwritting the statistics via STATS_STREAM
https://dba.stackexchange.com/questions/235517/updating-statistics-using-stats-stream-or-with-fullscan
-- ============================================================

DROP TABLE IF EXISTS dbo.Fruits
CREATE TABLE dbo.Fruits
(
    Name    VARCHAR(20) NOT NULL,
    Type    VARCHAR(20) NOT NULL,
    Amount  INT  NOT NULL
);
CREATE NONCLUSTERED INDEX IX_Fruits_Name on dbo.Fruits(Name)
GO


-- prepare fake statistics to overwrite the real values
INSERT INTO dbo.Fruits (Name, Type, Amount)
VALUES ('apple', 'Granny Smith', 10), ('banana', 'baby', 20), ('banana', 'red', 30)
GO

-- update stats
UPDATE STATISTICS dbo.Fruits(IX_Fruits_Name) 
WITH FULLSCAN
DBCC SHOW_STATISTICS ('dbo.Fruits','IX_Fruits_Name')  WITH HISTOGRAM;


DROP TABLE IF EXISTS #StatsWithStream
CREATE TABLE #StatsWithStream
(
    Stream VARBINARY(MAX) NOT NULL,
    Rows INT NOT NULL,
    Pages INT NOT NULL
);

INSERT INTO #StatsWithStream 
EXEC ('DBCC SHOW_STATISTICS (''dbo.Fruits'', ''IX_Fruits_Name'')  WITH STATS_STREAM');
GO

-- select * from #StatsWithStream 



-- fill with real values
TRUNCATE TABLE dbo.Fruits
GO

INSERT INTO dbo.Fruits (Name, Type, Amount)
VALUES ('orange', 'Valencia', 5), ('kiwi', 'golden', 25), ('strawberry', 'albion', 35)
GO 1000

-- update stats
UPDATE STATISTICS dbo.Fruits(IX_Fruits_Name) 
WITH FULLSCAN
DBCC SHOW_STATISTICS ('dbo.Fruits','IX_Fruits_Name')  WITH HISTOGRAM; 


--check the plan (Scan)
SELECT * FROM dbo.Fruits
WHERE Name = 'orange'
OPTION (RECOMPILE)


-- overwrite the statistics with custom values
DECLARE @sql NVARCHAR(MAX);
SET @sql = 
    (
    SELECT 'UPDATE STATISTICS dbo.Fruits(IX_Fruits_Name) 
    WITH STATS_STREAM = 0x' + CAST('' AS XML).value('xs:hexBinary(sql:column("stream"))','NVARCHAR(MAX)') 
    FROM #StatsWithStream 
    );
EXEC (@sql);
GO
DBCC SHOW_STATISTICS ('dbo.Fruits', 'IX_Fruits_Name')  WITH HISTOGRAM


--check the plan (seek + look up)
SELECT * FROM dbo.Fruits
WHERE Name = 'orange'
OPTION (RECOMPILE)


-- overwrite back to real values - FULLSCAN
UPDATE STATISTICS dbo.Fruits(IX_Fruits_Name) 
WITH FULLSCAN
DBCC SHOW_STATISTICS ('dbo.Fruits','IX_Fruits_Name')  WITH HISTOGRAM; 

--check the plan (Scan)
SELECT * FROM dbo.Fruits
WHERE Name = 'orange'
OPTION (RECOMPILE)