/*******************************************************************************
** Supporting table: dbo.PerfLongQueries
** Stores long-running query stats from sys.dm_exec_query_stats.
** Retention: 1 month. Threshold: max_worker_time > 180 s (parallel) or
** max_elapsed_time > 180 s (single-threaded). QueryHash is the natural key;
** rows are upserted via MERGE (no duplicates per query fingerprint).
** Populated twice a day (10:00-10:15 and 22:00-22:15 UTC).
** Run this DDL once before the first execution of dbo.PutPerfLongQueries.
*******************************************************************************/
/*
CREATE TABLE dbo.PerfLongQueries
(
    DbName                VARCHAR(20)    NOT NULL,
    LastExecutionTime     DATETIME       NOT NULL,
    SQLText               NVARCHAR(MAX)  NOT NULL,
    NameSP                VARCHAR(100)       NULL,          -- schema.object_name of the owning SP, if any
    QueryPlan             XML                NULL,
    ExecutionCount        INT            NOT NULL,
    AvgIOInPages          BIGINT             NULL,          -- (total_logical_reads + total_logical_writes) / execution_count
    AvgReadsInPages       BIGINT             NULL,
    AvgWritesInPages      BIGINT             NULL,
    AvgCPUTimeInSec       NUMERIC(28, 8)     NULL,
    TotalCPUTimeInSec     NUMERIC(28, 8)     NULL,
    MaxCPUTimeInSec       NUMERIC(28, 8)     NULL,
    AvgDOP                INT                NULL,          -- average degree of parallelism
    AvgElapsedTimeInSec   NUMERIC(28, 8)     NULL,
    TotalElapsedTimeInSec NUMERIC(28, 8)     NULL,
    MaxElapsedTimeInSec   NUMERIC(28, 8)     NULL,
    TotalRows             BIGINT             NULL,
    MaxRows               BIGINT             NULL,
    QueryHash             BINARY(8)      NOT NULL           -- MERGE join key; unique per query fingerprint
);
*/

CREATE PROCEDURE dbo.PutPerfLongQueries
AS
BEGIN
/******************************************************************************
** Description - Insert Long running queries:
    max_worker_time/1000000.0 > 180 sec   -- highly parallel queries
    OR max_elapsed_time/1000000.0 > 180 sec  -- slow single threaded queries
**
*******************************************************************************/
SET NOCOUNT ON;

BEGIN TRY
    BEGIN
        DELETE FROM dbo.PerfLongQueries WHERE [LastExecutionTime] < DATEADD(MONTH, -1, GETUTCDATE())

        DECLARE @CurrentTime TIME = GETUTCDATE();

        IF @CurrentTime BETWEEN '10:00:00' AND '10:15:00' OR @CurrentTime BETWEEN '22:00:00' AND '22:15:00' --Run twice a day in the morning/evening
        BEGIN
            DROP TABLE IF EXISTS #PerfLongQueries

            CREATE TABLE #PerfLongQueries
            (
                DbName VARCHAR(20) NOT NULL,
                LastExecutionTime DATETIME NOT NULL,
                SQLText NVARCHAR(MAX) NOT NULL,
                NameSP VARCHAR(100) NULL,
                QueryPlan XML NULL,
                ExecutionCount INT NOT NULL,
                AvgIOInPages BIGINT NULL,
                AvgReadsInPages BIGINT NULL,
                AvgWritesInPages BIGINT NULL,
                AvgCPUTimeInSec NUMERIC(28, 8) NULL,
                TotalCPUTimeInSec NUMERIC(28, 8) NULL,
                MaxCPUTimeInSec NUMERIC(28, 8) NULL,
                AvgDOP INT NULL,
                AvgElapsedTimeInSec NUMERIC(28, 8) NULL,
                TotalElapsedTimeInSec NUMERIC(28, 8) NULL,
                MaxElapsedTimeInSec NUMERIC(28, 8) NULL,
                TotalRows BIGINT NULL,
                AvgRows BIGINT NULL,
                MaxRows BIGINT NULL,
                QueryHash BINARY(8) NOT NULL
            )

            INSERT INTO #PerfLongQueries
            SELECT
                DB_NAME(qt.dbid) AS DbName,
                qs.last_execution_time AS LastExecutionTime,
                SUBSTRING(qt.text, (qs.statement_start_offset/2)+1,
                ((
                    CASE qs.statement_end_offset
                    WHEN -1 THEN DATALENGTH(qt.text)
                    ELSE qs.statement_end_offset
                    END - qs.statement_start_offset)/2)+1) AS [SQLText],
                SCHEMA_NAME(o.schema_id) + '.' + OBJECT_NAME(o.object_id) AS NameSP,
                qp.query_plan AS QueryPlan,
                qs.execution_count AS ExecutionCount,
                (qs.total_logical_reads+qs.total_logical_writes)/qs.execution_count AS AvgIOInPages,
                qs.total_logical_reads/qs.execution_count AS AvgReadsInPages,
                qs.total_logical_writes/qs.execution_count AS AvgWritesInPages,
                qs.total_worker_time/(qs.execution_count*1000000.0) AS AvgCPUTimeInSec,
                qs.total_worker_time/1000000.0 AS TotalCPUTimeInSec,       -- Amount of CPU cycles (in sec) spent by the thread on a
                qs.max_worker_time/1000000.0 AS MaxCPUTimeInSec,           -- Max amount of CPU cycles (in sec) spent by the thread
                qs.total_dop/qs.execution_count AS AvgDOP,
                qs.total_elapsed_time/(qs.execution_count*1000000.0) AS AvgElapsedTimeInSec,
                qs.total_elapsed_time/1000000.0 AS TotalElapsedTimeInSec,  -- The time from start to end. total_worker_time (CPU) + s
                qs.max_elapsed_time/1000000.0 AS MaxElapsedTimeInSec,
                qs.total_rows AS TotalRows,                                 -- Total number of rows returned by the query
                qs.total_rows/qs.execution_count AS AvgRows,
                qs.max_rows AS MaxRows,
                qs.query_hash AS QueryHash
            FROM sys.dm_exec_query_stats qs
            CROSS APPLY sys.dm_exec_sql_text(qs.plan_handle) qt
            CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle) qp
            LEFT JOIN sys.objects o
                ON qt.objectid = o.object_id
            WHERE 1=1
            AND qt.dbid = DB_ID()
            AND (qs.max_worker_time/1000000.0 > 180   -- highly parallel queries
                OR qs.max_elapsed_time/1000000.0 > 180  -- slow single threaded queries
                )

            -- delete potential duplicates on QueryHash - if the same query occurs multiple times
            ;WITH dupl as (
            SELECT *, ROW_NUMBER() OVER (PARTITION BY QueryHash ORDER BY LastExecutionTime DESC) AS rn
            FROM #PerfLongQueries
            )
            DELETE FROM dupl
            WHERE rn > 1

            ;MERGE dbo.PerfLongQueries AS target
            USING #PerfLongQueries AS source
            ON target.QueryHash = source.QueryHash
            -- Insert New Rows
            WHEN NOT MATCHED BY TARGET THEN
            INSERT
            (
                DbName
                ,LastExecutionTime          ,SQLText
                ,NameSP                     ,QueryPlan
                ,ExecutionCount             ,AvgIOInPages
                ,AvgReadsInPages            ,AvgWritesInPages
                ,AvgCPUTimeInSec            ,TotalCPUTimeInSec
                ,MaxCPUTimeInSec            ,AvgDOP
                ,AvgElapsedTimeInSec        ,TotalElapsedTimeInSec
                ,MaxElapsedTimeInSec        ,TotalRows
                ,MaxRows                    ,QueryHash
            )
            VALUES
            (
                source.DbName
                ,source.LastExecutionTime   ,source.SQLText
                ,source.NameSP              ,source.QueryPlan
                ,source.ExecutionCount      ,source.AvgIOInPages
                ,source.AvgReadsInPages     ,source.AvgWritesInPages
                ,source.AvgCPUTimeInSec     ,source.TotalCPUTimeInSec
                ,source.MaxCPUTimeInSec     ,source.AvgDOP
                ,source.AvgElapsedTimeInSec ,source.TotalElapsedTimeInSec
                ,source.MaxElapsedTimeInSec ,source.TotalRows
                ,source.MaxRows             ,source.QueryHash
            )
            -- Update Rows that have changed
            WHEN MATCHED THEN
            UPDATE SET
                target.LastExecutionTime = source.LastExecutionTime,
                target.ExecutionCount = source.ExecutionCount,
                target.AvgIOInPages = source.AvgIOInPages,
                target.AvgReadsInPages = source.AvgReadsInPages,
                target.AvgWritesInPages = source.AvgWritesInPages,
                target.AvgCPUTimeInSec = source.AvgCPUTimeInSec,
                target.TotalCPUTimeInSec = source.TotalCPUTimeInSec,
                target.MaxCPUTimeInSec = source.MaxCPUTimeInSec,
                target.AvgDOP = source.AvgDOP,
                target.AvgElapsedTimeInSec = source.AvgElapsedTimeInSec,
                target.TotalElapsedTimeInSec = source.TotalElapsedTimeInSec,
                target.MaxElapsedTimeInSec = source.MaxElapsedTimeInSec,
                target.TotalRows = source.TotalRows,
                target.MaxRows = source.MaxRows
            ;

            DROP TABLE IF EXISTS #PerfLongQueries
        END
    END
END TRY
BEGIN CATCH
    DECLARE
        @ErrorSeverity INT = ERROR_SEVERITY(),
        @ErrorState INT = ERROR_STATE(),
        @ErrorProcedure NVARCHAR(126) = ERROR_PROCEDURE(),
        @ErrorLine INT = ERROR_LINE(),
        @ErrorMessage NVARCHAR(2048) = OBJECT_NAME(@@procid) + ': ' + ERROR_MESSAGE();

    IF (XACT_STATE() = -1)
        ROLLBACK;

    EXEC icon.LogError

    RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState, @ErrorProcedure, @ErrorLine);
END CATCH
END
