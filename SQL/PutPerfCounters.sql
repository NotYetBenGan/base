/*******************************************************************************
** Supporting table: dbo.PerfCounters
** Stores I/O, memory, and buffer-pool performance counter snapshots.
** Retention: 6 months. Type values: 'Absolute' | 'Cumulative' | 'Ratio'.
** Run this DDL once before the first execution of dbo.PutPerfCounters.
*******************************************************************************/
/*
CREATE TABLE dbo.PerfCounters
(
    LogDate      DATETIME      NOT NULL,          -- UTC snapshot time (GETUTCDATE())
    CounterName  VARCHAR(128)  NOT NULL,          -- counter identifier, e.g. 'Page Life expectancy'
    CounterValue DECIMAL(28, 4)    NULL,          -- counter reading; NULL allowed for ratio base rows
    Type         VARCHAR(20)   NOT NULL,          -- 'Absolute' | 'Cumulative' | 'Ratio'
    Comments     VARCHAR(255)      NULL           -- human-readable annotation or raw cumulative value
);
*/

CREATE PROCEDURE dbo.PutPerfCounters
AS
BEGIN
/******************************************************************************
** Description - Insert I/O and Memory usage stats in dbo.PerfCounters
Recommended values:
'Buffer Cache Hit ratio' > 95% - Percentage of pages found in the buffer cache without having to read from disk
'Page Life expectancy' > 300 * 'Total Server Memory (GB)' / 4GB == 9600sec - Number of seconds a page will stay in the buffer pool without references
'Free List Stalls / sec' < 2 - Number of requests per second that had to wait for a free page
'Page writes/sec', 'Page writes/sec' < 90 (?) - Number of physical I/O operations to disk per second, not the number of pages!
**
*******************************************************************************/
SET NOCOUNT ON;

BEGIN TRY
    BEGIN
        DELETE FROM dbo.PerfCounters WHERE [LogDate] < DATEADD(MONTH, -6, GETUTCDATE())

        DECLARE @PreviousLogDate DATETIME = (SELECT MAX(LogDate) FROM dbo.PerfCounters WHERE Type = 'Cumulative')

        ;WITH base AS
        (
            SELECT
                GETUTCDATE() AS LogDate,
                counter_name AS CounterName,
                cntr_value AS CounterValue,
                CASE WHEN cntr_type IN (65792, 65536) THEN 'Absolute'
                    WHEN cntr_type IN (272696576) THEN 'Cumulative'
                    WHEN cntr_type IN (537003264, 1073939712) THEN 'Ratio'
                END AS Type,
                CASE WHEN cntr_type IN (272696576) THEN CAST(cntr_value AS VARCHAR) END AS Comments --keep cumulative values in Comments
            FROM sys.dm_os_performance_counters
            WHERE OBJECT_NAME LIKE '%Manager%'
            AND counter_name IN
            ('Page Life expectancy', 'Page reads/sec', 'Page writes/sec', 'Checkpoint pages/sec', 'Database Cache Memory (KB)', 'Free Memory (KB)', 'Stolen Server Memory (KB)',
            'Total Server Memory (KB)', 'Buffer cache hit ratio', 'Target Server Memory (KB)', 'Free List Stalls/sec', 'Buffer cache hit ratio base')

            UNION ALL

            SELECT GETUTCDATE(), 'Available physical memory', available_physical_memory_kb, 'Absolute', system_memory_state_desc
            FROM sys.dm_os_sys_memory

            UNION ALL

            SELECT GETUTCDATE(), 'Memory optimized clerk (MB)', SUM(pages_kb), 'Absolute', CONCAT(SUM(CASE WHEN name LIKE CONCAT('%', DB_ID(), '%') THEN pages_kb ELSE 0 END ), ' KB on this DB')
            FROM sys.dm_os_memory_clerks
            WHERE type LIKE '%xtp%'

            UNION ALL

            SELECT GETUTCDATE(),
                    '% tempdb TranLog space used',
                    100 *(s.cntr_value / 1024/ 1024) / (t.cntr_value / 1024/ 1024) AS CounterValue,
                    'Absolute' AS Type,
                    CAST(SUM(t.cntr_value / 1024/ 1024) AS VARCHAR) + ' GB total tempdb TranLog space' AS Comments
            FROM sys.dm_os_performance_counters s
            JOIN sys.dm_os_performance_counters t ON 1=1
            AND t.instance_name = 'tempdb'
            AND t.counter_name LIKE 'Log File(s) Size (KB)%'
            WHERE 1=1
            AND s.counter_name LIKE 'Log File(s) Used%'
            AND s.instance_name = 'tempdb'
            GROUP BY t.cntr_value, s.cntr_value

            UNION ALL

            SELECT GETUTCDATE(),
                    '% TranLog space used',
                    100 *(s.cntr_value / 1024 / 1024) / (t.cntr_value / 1024 / 1024) AS CounterValue,
                    'Absolute' AS Type,
                    CAST(SUM(t.cntr_value / 1024/ 1024) AS VARCHAR) + ' GB total TranLog space' AS Comments
            FROM sys.dm_os_performance_counters s
            JOIN sys.dm_os_performance_counters t ON 1=1
            AND t.instance_name = DB_NAME()
            AND t.counter_name LIKE 'Log File(s) Size (KB)%'
            WHERE 1=1
            AND s.counter_name LIKE 'Log File(s) Used%'
            AND s.instance_name = DB_NAME()
            GROUP BY t.cntr_value, s.cntr_value

            UNION ALL

            SELECT
                GETUTCDATE(),
                'LogSend Queue (KB)',
                log_send_queue_size AS CounterValue,
                'Absolute' AS Type,
                'Num of log records not yet sent to the secondary DB, in KB' as Comment
            FROM sys.dm_hadr_database_replica_states
            WHERE 1=1 AND database_id = DB_ID()
            AND log_send_queue_size IS NOT NULL

            UNION ALL

            SELECT
                GETUTCDATE(),
                'Redo Queue (KB)',
                redo_queue_size AS CounterValue,
                'Absolute' AS Type,
                'Num of log records not yet redone on the secondary DB, in KB' as Comment
            FROM sys.dm_hadr_database_replica_states
            WHERE 1=1 AND database_id = DB_ID()
            AND redo_queue_size IS NOT NULL

            UNION ALL

            SELECT
                GETUTCDATE(),
                'SecondsSinceLastRedo',
                DATEDIFF(SECOND, last_redone_time, GETDATE()) AS CounterValue,
                'Absolute' AS Type,
                'Time since the last log record was redone on the secondary DB, in seconds' as Comment
            FROM sys.dm_hadr_database_replica_states
            WHERE 1=1 AND database_id = DB_ID()
                AND last_redone_time IS NOT NULL
        ),
        previous_cumulative AS
        (
            SELECT
                p.CounterName,
                p.CounterValue,
                p.Comments
            FROM dbo.PerfCounters p
            WHERE p.Type = 'Cumulative' AND p.LogDate = @PreviousLogDate
        ),
        cumulative AS
        (
        SELECT
            base.LogDate,
            base.CounterName,
            CASE WHEN TRY_CONVERT(BIGINT, base.Comments) - COALESCE(TRY_CONVERT(BIGINT, p.Comments), p.CounterValue, 0) < 0 THEN 0
                ELSE (TRY_CONVERT(BIGINT, base.Comments) - COALESCE(TRY_CONVERT(BIGINT, p.Comments), p.CounterValue, 0))/DATEDIFF(SECOND, @PreviousLogDate, GETUTCDATE())
                END AS CounterValue,
            base.Type,
            base.Comments
        FROM base
        LEFT JOIN previous_cumulative p
            ON base.CounterName = p.CounterName
        WHERE base.Type = 'Cumulative'
        ),
        ratio AS (
        SELECT
            base.LogDate,
            'Buffer Cache Hit Ratio' AS CounterName,
            MIN(CounterValue)* 100.0/MAX(CounterValue) AS CounterValue,
            'Ratio' AS Type,
            'Should be > 95%' AS Comments
        FROM base
        WHERE Type = 'Ratio'
        GROUP BY LogDate
        ),
        Absolute AS (
        SELECT
            base.LogDate,
            base.CounterName,
            base.CounterValue,
            base.Type,
            CASE
                WHEN CounterName = 'Total Server Memory (KB)' THEN 'Cache + Free + Stolen'
                WHEN CounterName = 'Target Server Memory (KB)' THEN 'Ideal amount to have'
                WHEN CounterName = 'Stolen Server Memory (KB)' THEN 'Non cache (locks, plans)'
                ELSE base.Comments
            END as Comments
        FROM base
        WHERE Type = 'Absolute'

        UNION ALL

        SELECT
            GETUTCDATE() AS LogDate,
            CONCAT('% ', fg.name,' space used') AS CounterName,
            100 * SUM(FILEPROPERTY(s.name, 'SpaceUsed') * 8.) / SUM(s.size * 8.) AS CounterValue,
            'Absolute' AS Type,
            CAST(SUM(s.size * 8 / 1024/ 1024) AS VARCHAR) + ' GB total FG space' AS Comments
        FROM sys.filegroups fg
        INNER JOIN sys.database_files s
            ON s.data_space_id = fg.data_space_id
        WHERE 1=1
            AND s.type_desc = 'ROWS'
            AND fg.name IN ('AXIS_Group1', 'PRIMARY')
        GROUP BY fg.name
        )

        INSERT INTO [dbo].[PerfCounters] ([LogDate],[CounterName],[CounterValue],[Type],[Comments])
        SELECT
            [LogDate]
            ,[CounterName] = RTRIM([CounterName])
            ,[CounterValue]
            ,[Type]
            ,[Comments]
        FROM (
            SELECT * FROM cumulative           UNION ALL
            SELECT * FROM ratio                UNION ALL
            SELECT * FROM Absolute
        ) AS [A]
        OPTION (RECOMPILE);

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
