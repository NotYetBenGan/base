DROP FUNCTION IF EXISTS dbo.UDF_GetBitsFromBytes;
GO

CREATE OR ALTER FUNCTION dbo.UDF_GetBitsFromBytes(@Bytes VARBINARY(MAX))
/****************************************************************************************************
Calculate bits for a binary value.

For each bit position, the function checks whether the corresponding bit is set in the input binary value using a bitwise AND operation:
 - (CAST(SUBSTRING(@Bytes, CEILING((ID + 1) / 8.0), 1) AS INT) & BitValue) > 0
****************************************************************************************************/
RETURNS VARCHAR(MAX)
AS
BEGIN
    DECLARE @Result VARCHAR(MAX) = '';
    DECLARE @ByteCount INT = DATALENGTH(@Bytes); -- Get the number of bytes in the input
    DECLARE @BitTable TABLE (ID INT, BitValue INT);

    -- Populate the bit table dynamically based on the number of bytes
    WITH BitValues AS (
        SELECT 
            0 AS ID, 
            POWER(2, 0) AS BitValue
        UNION ALL
        SELECT 
            ID + 1 AS ID, 
            POWER(2, (ID + 1) % 8) AS BitValue
        FROM BitValues
        WHERE ID + 1 < @ByteCount * 8 -- Limit to the total number of bits (bytes * 8)
    )
    INSERT INTO @BitTable
    SELECT ID, BitValue
    FROM BitValues;

    -- Generate the bit string
    SELECT @Result = @Result + 
        CONVERT(VARCHAR(1), 
            CASE 
                WHEN (CAST(SUBSTRING(@Bytes, CEILING((ID + 1) / 8.0), 1) AS INT) & BitValue) > 0 
                THEN 1 
                ELSE 0 
            END)
    FROM @BitTable
    ORDER BY ID; -- Ensure bits are in the correct order

    RETURN @Result;
END;
GO