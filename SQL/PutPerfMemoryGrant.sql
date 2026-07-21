/*******************************************************************************
** Supporting table: dbo.PerfMemoryGrant
** Stores memory grant events from XEvent session 'MemoryGrant' (UAT only).
** Retention: 1 month. Only events where ideal_memory_kb > 100,000 KB and
** a matching 'query_memory_grant_blocking' or 'query_memory_grant_usage' event
** exists within 1 second for the same session.
** FileOffset tracks the last processed XEvent file position to avoid re-reads.
** Run this DDL once before the first execution of dbo.PutPerfMemoryGrant.
*******************************************************************************/
/*
CREATE TABLE dbo.PerfMemoryGrant
(
    DbName            VARCHAR(20)   NOT NULL,
    EventDate         DATETIME2     NOT NULL,          -- UTC timestamp from XEvent file (timestamp_utc)
    SessionId         INT           NOT NULL,
    FileOffset        BIGINT        NOT NULL,          -- XEvent file offset; used to resume incremental reads
    [Text]            NVARCHAR(MAX)     NULL,          -- SQL statement text from the event
    ObjectName        VARCHAR(80)       NULL,
    UserName          VARCHAR(50)       NULL,
    EventName         VARCHAR(50)       NULL,          -- e.g. 'query_memory_grant_blocking', 'query_memory_grant_usage'
    ideal_memory_kb   BIGINT            NULL,          -- memory the query would ideally receive
    granted_percent   BIGINT            NULL,          -- percentage of ideal memory actually granted
    granted_memory_kb BIGINT            NULL,
    usage_percent     BIGINT            NULL,
    used_memory_kb    BIGINT            NULL,
    duration_ms       BIGINT            NULL,          -- event duration in milliseconds (XEvent duration / 1000)
    physical_reads    BIGINT            NULL,
    logical_reads     BIGINT            NULL,
    writes            BIGINT            NULL,
    cpu_time          BIGINT            NULL,
    [RowCount]        BIGINT            NULL,
    QueryPlan         XML               NULL
);
*/

CREATE PROCEDURE dbo.PutPerfMemoryGrant
AS
BEGIN
/******************************************************************************
** Description - Insert useful stats from XE 'MemoryGrant' in dbo.PerfMemoryGrant
*******************************************************************************/
SET NOCOUNT ON;

BEGIN TRY
    DECLARE @EnvironmentType VARCHAR(10) = (SELECT TOP 1 NULLIF(ParamValue, '') FROM icon.UDF_GetRequestTypeParameterValue(0, 'EnvironmentType'));

    IF @EnvironmentType = 'UAT'
    BEGIN
        DELETE FROM dbo.PerfMemoryGrant
        WHERE [EventDate] < DATEADD(MONTH, -1, GETUTCDATE());

        DECLARE @Filename AS NVARCHAR(500),
            @PrevFileOffset AS BIGINT,
            @IdealMemoryThresholdKB BIGINT = 100000,
            @NameSP VARCHAR(128) = OBJECT_SCHEMA_NAME(@@PROCID) + '.' + OBJECT_NAME(@@PROCID);

        --Get FileName
        SELECT @Filename = CAST(t.target_data AS XML).value('(EventFileTarget/File/@name)[1]', 'VARCHAR(MAX)')
        FROM sys.dm_xe_sessions AS s
            INNER JOIN sys.dm_xe_session_targets AS t
                ON s.address = t.event_session_address
        WHERE t.target_name = 'event_file'
            AND s.name = 'MemoryGrant';

        SELECT @PrevFileOffset = MAX(FileOffset)
        FROM dbo.PerfMemoryGrant;

        -- Check if @PrevFileOffset makes sense for the current file state. If yes - we will just pass by
        BEGIN TRY
            IF EXISTS(
            SELECT TOP 1
                fn.file_offset
            FROM sys.fn_xe_file_target_read_file(  @Filename,      -- path to the files to read
                NULL,                               -- not in use (Korotkevich p.533)
                @Filename,                          -- first file to read from path
                @PrevFileOffset                     -- initial_offset
            ) fn
            WHERE 1 = 1
                AND DATEDIFF(MINUTE, fn.timestamp_utc, GETUTCDATE()) <= 15)

                SELECT @PrevFileOffset = @PrevFileOffset

        END TRY
        -- If no - the will be error raised, that's why this logic is wrapped in TRY/CATCH
        -- Get new @PrevFileOffset to start with
        BEGIN CATCH
            SELECT @PrevFileOffset = MIN(fn.file_offset)
            FROM sys.fn_xe_file_target_read_file(  @Filename,  -- path to the files to read
                NULL,                              -- not in use (Korotkevich p.533)
                NULL,                              -- first file to read from path
                NULL                               -- initial_offset
            ) fn
            WHERE 1 = 1
                AND DATEDIFF(MINUTE, fn.timestamp_utc, GETUTCDATE()) <= 15;
        END CATCH;

        DROP TABLE IF EXISTS #TargetData;
        SELECT CAST(fn.event_data AS XML) AS TargetData,
            fn.file_offset,
            fn.timestamp_utc
        INTO #TargetData
        FROM sys.fn_xe_file_target_read_file(  @Filename,   -- path to the files to read
            NULL,                               -- not in use (Korotkevich p.533)
            @Filename,                          -- first file to read from path
            @PrevFileOffset                     -- initial_offset
        ) fn
        WHERE 1 = 1
            AND DATEDIFF(MINUTE, fn.timestamp_utc, GETUTCDATE()) <= 15;

        DROP TABLE IF EXISTS #MemoryGrant;
        SELECT
            DB_NAME() AS DbName,
            td.timestamp_utc AS EventDate,
            CAST(n.value('(action[@name="session_id"]/value)[1]', 'NVARCHAR(MAX)') AS INT) AS SessionId,
            n.value('(action[@name="sql_statement"]/value)[1]', 'NVARCHAR(MAX)') AS [Text],
            td.file_offset AS FileOffset,
            n.value('(action[@name="object_name"]/value)[1]', 'NVARCHAR(MAX)') AS ObjectName,
            n.value('(action[@name="username"]/value)[1]', 'NVARCHAR(MAX)') AS UserName,
            n.value('(@name)[1]', 'VARCHAR(50)') AS EventName,
            n.value('(data[@name="ideal_memory_kb"]/value)[1]', 'BIGINT') AS ideal_memory_kb,
            n.value('(data[@name="granted_percent"]/value)[1]', 'BIGINT') AS granted_percent,
            n.value('(data[@name="granted_memory_kb"]/value)[1]', 'BIGINT') AS granted_memory_kb,
            n.value('(data[@name="usage_percent"]/value)[1]', 'BIGINT') AS usage_percent,
            n.value('(data[@name="used_memory_kb"]/value)[1]', 'BIGINT') AS used_memory_kb,
            n.value('(data[@name="duration"]/value)[1]', 'BIGINT') / 1000 AS duration_ms,
            n.value('(data[@name="physical_reads"]/value)[1]', 'BIGINT') AS physical_reads,
            n.value('(data[@name="logical_reads"]/value)[1]', 'BIGINT') AS logical_reads,
            n.value('(data[@name="writes"]/value)[1]', 'BIGINT') AS writes,
            n.value('(data[@name="cpu_time"]/value)[1]', 'BIGINT') AS cpu_time,
            n.value('(data[@name="row_count"]/value)[1]', 'BIGINT') AS [RowCount],
            n.value('xs:hexBinary(Action[@name="plan_handle"]/value)[1]', 'VARBINARY(64)') AS PlanHandle
        INTO #MemoryGrant
        FROM #TargetData td
            CROSS APPLY td.TargetData.nodes('//event') AS q(n)
        WHERE 1 = 1
            AND n.value('(action[@name="database_name"]/value)[1]', 'NVARCHAR(MAX)') = DB_NAME()

        CREATE CLUSTERED INDEX [CLX_MemoryGrant] ON #MemoryGrant (EventDate, SessionId, EventName)

        INSERT INTO dbo.PerfMemoryGrant
        SELECT mg.DbName,
                mg.EventDate,
                mg.SessionId,
                mg.FileOffset,
                mg.[Text],
                mg.ObjectName,
                mg.UserName,
                mg.EventName,
                mg.ideal_memory_kb,
                mg.granted_percent,
                mg.granted_memory_kb,
                mg.usage_percent,
                mg.used_memory_kb,
                mg.duration_ms,
                mg.physical_reads,
                mg.logical_reads,
                mg.writes,
                mg.cpu_time,
                mg.[RowCount],
                TRY_CAST(qp.query_plan AS XML) AS QueryPlan
        FROM #MemoryGrant mg
        OUTER APPLY sys.dm_exec_query_plan(mg.PlanHandle) qp
        WHERE 1=1
            AND EXISTS
            (
                SELECT 1
                FROM #MemoryGrant mg2
                WHERE mg2.ideal_memory_kb > @IdealMemoryThresholdKB
                    AND mg2.EventName IN ('query_memory_grant_blocking', 'query_memory_grant_usage')
                    AND (DATEDIFF(SECOND, mg2.EventDate, mg.EventDate) <= 1)
                    AND (DATEDIFF(SECOND, mg.EventDate, mg2.EventDate) <= 1)
                    AND mg2.SessionId = mg.SessionId
            )

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
