DROP FUNCTION IF EXISTS dbo.UDF_ConvertLSN;
GO

CREATE OR ALTER FUNCTION dbo.UDF_ConvertLSN(@LSN NVARCHAR(64))
/****************************************************************************************************
LSN (Log Sequence Number) in SQL Server is a 96-bit composite structure made up of three parts:
- VLF sequence number (FileSeqNo) – 4 bytes
- Block number (LogBlockOffset) – 4 bytes
- Slot number (SlotId) – 2 bytes

Because SQL Server doesn’t have a native 96-bit integer type (CPUs don’t natively support it), 
DMVs and functions (like sys.fn_dblog) expose LSNs as a string representation (NVARCHAR(64)), e.g.:

FileSeqNo | LBOffset | SlId 
----------|----------|------
'0000002b:000001a3:0001'
****************************************************************************************************/
RETURNS NVARCHAR(64)
AS
BEGIN
    DECLARE @FileSeqNo BIGINT, 
            @LBOffset BIGINT, 
            @SlId BIGINT;
    DECLARE @ConvertedLSN NVARCHAR(64);

    -- Extract and convert the three parts of the LSN
    SET @FileSeqNo = CONVERT(BIGINT, CONVERT(VARBINARY, SUBSTRING(@LSN, 1, 8), 2));
    SET @LBOffset =  CONVERT(BIGINT, CONVERT(VARBINARY, SUBSTRING(@LSN, 10, 8), 2));
    SET @SlId =		 CONVERT(BIGINT, CONVERT(VARBINARY, SUBSTRING(@LSN, 19, 4), 2));

    -- Combine the parts into the final LSN format
    SET @ConvertedLSN = CAST(@FileSeqNo AS NVARCHAR) + ':' + 
                        CAST(@LBOffset AS NVARCHAR) + ':' + 
                        CAST(@SlId AS NVARCHAR);

    RETURN @ConvertedLSN;
END;
GO