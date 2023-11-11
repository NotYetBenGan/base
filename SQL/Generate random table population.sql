USE WideWorldImportersDW
GO

DECLARE @obj INT = OBJECT_ID('Dimension.Customer')
	  , @DeleteSql NVARCHAR(MAX)	
      , @InsertSql NVARCHAR(MAX)
      , @cnt INT = 1000000


SELECT @DeleteSql = '
DELETE FROM ' + QUOTENAME(OBJECT_SCHEMA_NAME(@obj)) + '.' + QUOTENAME(OBJECT_NAME(@obj)) + ''

--CTE generates 10^8 rows (1) for string columns population
;WITH
    E1(N) AS (
        SELECT * FROM (
            VALUES
                (1),(1),(1),(1),(1),
                (1),(1),(1),(1),(1)
        ) t(N)
    ),
    E2(N) AS (SELECT 1 FROM E1 a, E1 b),
    E4(N) AS (SELECT 1 FROM E2 a, E2 b),
    E8(N) AS (SELECT 1 FROM E4 a, E4 b)

SELECT @InsertSql =
';WITH
    E1(N) AS (
        SELECT * FROM (
            VALUES
                (1),(1),(1),(1),(1),
                (1),(1),(1),(1),(1)
        ) t(N)
    ),
    E2(N) AS (SELECT 1 FROM E1 a, E1 b),
    E4(N) AS (SELECT 1 FROM E2 a, E2 b),
    E8(N) AS (SELECT 1 FROM E4 a, E4 b)
    
/*INSERT INTO ' + QUOTENAME(OBJECT_SCHEMA_NAME(@obj)) + '.' + QUOTENAME(OBJECT_NAME(@obj)) + '(' +
    STUFF((
        SELECT ', ' + QUOTENAME(name)
        FROM sys.columns c
        WHERE c.[object_id] = @obj
            AND c.is_identity = 0
            AND c.is_computed = 0
	    FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 2, '')
+ ')*/

SELECT TOP(' + CAST(@cnt AS VARCHAR(10)) + ') ' +
STUFF((
	SELECT '
    , ' + QUOTENAME(name) + ' = ' +
        CASE 
            WHEN TYPE_NAME(c.system_type_id) IN (
                        'varchar', 'char', 'nvarchar',
                        'nchar', 'ntext', 'text'
                )
                THEN (
                    STUFF((
                        SELECT TOP(
                                CASE WHEN max_length = -1
                                    THEN CAST(RAND() * 10000 AS INT)
                                    ELSE max_length
                                END
                            /
                                CASE WHEN TYPE_NAME(c.system_type_id) IN ('nvarchar', 'nchar', 'ntext')
                                    THEN 2
                                    ELSE 1
                                END
                        ) '+SUBSTRING(x, (ABS(CHECKSUM(NEWID())) % 80) + 1, 1)'
                        FROM E8
                        FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 1, '')
                )
            WHEN TYPE_NAME(c.system_type_id) = 'tinyint'
                THEN '50 + CRYPT_GEN_RANDOM(10) % 50'
            WHEN TYPE_NAME(c.system_type_id) IN ('int', 'bigint', 'smallint')
                THEN 'CRYPT_GEN_RANDOM(10) % 25000'
            WHEN TYPE_NAME(c.system_type_id) = 'uniqueidentifier'
                THEN 'NEWID()'
            WHEN TYPE_NAME(c.system_type_id) IN ('decimal', 'float', 'money', 'smallmoney')
                THEN 'ABS(CAST(NEWID() AS BINARY(6)) % 1000) * RAND()'
            WHEN TYPE_NAME(c.system_type_id) IN ('datetime', 'smalldatetime', 'datetime2')
                THEN 'DATEADD(MINUTE, RAND(CHECKSUM(NEWID()))
                      *
                      (1 + DATEDIFF(MINUTE, ''20000101'', GETDATE())), ''20000101'')'
            WHEN TYPE_NAME(c.system_type_id) = 'bit'
                THEN 'ABS(CHECKSUM(NEWID())) % 2'
            WHEN TYPE_NAME(c.system_type_id) IN ('varbinary', 'image', 'binary')
                THEN 'CRYPT_GEN_RANDOM(5)'
            ELSE 'NULL'
        END
    FROM sys.columns c
    WHERE c.[object_id] = @obj
        AND c.is_identity = 0
        AND c.is_computed = 0
	FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 8, '
      ')
 + '
FROM E8
CROSS APPLY (
    SELECT x = ''0123456789-ABCDEFGHIJKLMNOPQRSTUVWXYZ abcdefghijklmnopqrstuvwxyz''
) t'

--EXEC sys.sp_executesql @DeleteSql 
EXEC sys.sp_executesql @InsertSql 
