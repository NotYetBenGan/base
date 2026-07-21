/*******************************************************************************
** Supporting table: dbo.PerfDeadlocks
** Stores deadlock graph XML captured from the system_health XEvent session.
** Retention: 6 months. Populated twice a day (10:00-10:15 and 22:00-22:15 UTC).
** Run this DDL once before the first execution of dbo.PutPerfDeadLocks.
*******************************************************************************/
/*
CREATE TABLE dbo.PerfDeadlocks
(
    LogDate   DATETIME NOT NULL,          -- UTC time when the row was inserted (GETUTCDATE())
    EventDate DATETIME NOT NULL,          -- UTC timestamp of the deadlock event from XEvent
    Text      XML      NOT NULL           -- deadlock graph XML from xml_deadlock_report event
);
*/

CREATE PROCEDURE dbo.PutPerfDeadLocks
AS
BEGIN
/******************************************************************************
** Description - Insert Page Life Expectancy and Memory usage stats in dbo.PerfCounters
*******************************************************************************/
SET NOCOUNT ON;
BEGIN TRY
    BEGIN
        DECLARE @CurrentDateTime DATETIME = GETUTCDATE();
        DECLARE @CurrentTime TIME = @CurrentDateTime,
            @HoursToCheck TINYINT = 12;

        DELETE FROM dbo.PerfDeadlocks WHERE [LogDate] < DATEADD(MONTH, -6, @CurrentDateTime)

        IF @CurrentTime BETWEEN '10:00:00' AND '10:15:00' OR @CurrentTime BETWEEN '22:00:00' AND '22:15:00' --Run twice a day in the morning/evening

        WITH EventFile AS (
        SELECT
            CAST(fn.event_data AS XML) AS TargetData
        FROM sys.dm_xe_session_targets st
        INNER JOIN sys.dm_xe_sessions s
            ON s.address = st.event_session_address
        CROSS APPLY sys.fn_xe_file_target_read_file(SUBSTRING(st.target_data, CHARINDEX('<File name=', st.target_data) + 12,
            CHARINDEX('.xel', st.target_data) - CHARINDEX('<File name=', st.target_data) - 8), NULL, NULL, NULL) fn
        WHERE s.name = 'system_health'
            AND st.target_name = 'event_file'
            AND fn.object_name = 'xml_deadlock_report'
            AND DATEDIFF(HOUR, fn.timestamp_utc, @CurrentDateTime) <= @HoursToCheck
        )
        INSERT INTO dbo.PerfDeadlocks
        (   LogDate,
            EventDate,
            Text
        )
        SELECT
            GETUTCDATE(),
            XEventData.XEvent.value('@timestamp', 'datetime') as EventDate,
            TRY_CAST(XEventData.XEvent.query('(data/value/deadlock)[1]') AS XML) AS [Text]
        FROM EventFile
        CROSS APPLY TargetData.nodes('//event') AS XEventData (XEvent)
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
