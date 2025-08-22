DROP FUNCTION IF EXISTS dbo.UDF_GetIntFromNext2Bytes;
GO

CREATE OR ALTER FUNCTION dbo.UDF_GetIntFromNext2Bytes(
    @VarbinaryString VARBINARY(8000),
    @N SMALLINT
)
/****************************************************************************************************
Extracts 2-byte segment from VARBINARY of size 8000, starting from the @N-th byte and interprets it as an integer.
****************************************************************************************************/
RETURNS INT
AS
BEGIN
    RETURN CONVERT(
        INT,
        CONVERT(BINARY(2), REVERSE(SUBSTRING(@VarbinaryString, @N, 2)))
    );
END;
GO