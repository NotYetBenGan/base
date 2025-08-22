/*********************************************************/
--0.0:

SELECT CAST(1234 AS BINARY(2)) --?

/*

Important! 
- SQL Server stores INT and other numeric data types in byte-swapped order (little-endian) because it runs on Intel x86/x64 architectures
- But! SQL Server treats CAST(1234 AS BINARY(2)) as a direct conversion of INT value into a binary, not swapped (big-endian)


1. 1234 in binary (2 bytes):
1234 = 1024 + 128 + 64 + 16 + 2 → 00000100 11010010 

2. Binary to Hex (for readability):
Group into bytes: 00000100 11010010  →  04 D2 - This is big-endian representation

3. SQL Server stores INT in little-endian:
Reversed byte order: 04 D2 → D2 04 

So, the 2-byte little-endian BINARY(2) representation of 1234 is: 0xD204
But 2-byte big-endian SELECT CONVERT(BINARY(2), 1234) is		: 0x04D2
*/

SELECT 
	SUBSTRING(0xD204, 1, 2),
	CONVERT(BINARY(2), REVERSE(SUBSTRING(0xD204, 1, 2))), 
	CONVERT(INT, CONVERT(BINARY(2), REVERSE(SUBSTRING(0xD204, 1, 2))))

/*********************************************************/

--0.1: dbo.UDF_GetIntFromNext2Bytes

SELECT dbo.UDF_GetIntFromNext2Bytes(0xD204, 1) 

/*********************************************************/

--0.2: UDF_GetBitsFromBytes 

SELECT dbo.UDF_GetBitsFromBytes(0x9100); -- Output: 0x9100 -> 0091 -> 0000 0000 1001 0001 -> '100010010'
SELECT dbo.UDF_GetBitsFromBytes(0x6800)


/*********************************************************/

--1. Fixed
--DROP TABLE IF EXISTS dbo.Fixed

CREATE TABLE dbo.Fixed
(
Col1 char(5) NOT NULL,
Col2 int NOT NULL,
Col3 char(3) NULL,
Col4 char(7) NOT NULL
);

--CREATE CLUSTERED INDEX CLX_Fixed ON dbo.Fixed(Col2)

INSERT dbo.Fixed 
VALUES 
	('ABCDE', 123, NULL, 'EightKB')

DELETE FROM dbo.Fixed

-- SELECT * FROM dbo.Fixed

/*********************************************************/

--2. Var
--DROP TABLE IF EXISTS dbo.Variable

CREATE TABLE dbo.Variable
(
Col1 char(3) NOT NULL,
Col2 varchar(250) NOT NULL,
Col3 varchar(20) NOT NULL,
Col4 varchar(5) NULL,
Col5 bit NULL,
Col6 bit NULL,
Col7 smallint NULL,
Col8 DATE NOT NULL,
Col9 numeric(18,4) NULL,
Col10 FLOAT NOT NULL,
Col11 bit NOT NULL,
Col12 bit NULL,
Col13 TINYINT NULL
);

INSERT dbo.Variable 
VALUES 
	('AAA', REPLICATE('X', 150), 'St. m. Vodny Stadion', '39A/3', NULL, 0, 123, '2025-08-21', 8.88, 9.9999, 0, 1, NULL); -- after INSERT -> 7799 free bytes

DELETE FROM dbo.Variable; 

-- SELECT * FROM dbo.Variable

/*********************************************************/

--3. BIT

--DROP TABLE IF EXISTS dbo.Bits

CREATE TABLE dbo.Bits
(
Col1 bit NULL,
Col2 bit NULL,
Col3 bit NULL,
Col4 bit NULL,
Col5 bit NULL,
Col6 bit NULL,
Col7 bit NULL,
Col8 bit NULL,
Col9 bit NULL,
Col10 bit NULL
);


INSERT dbo.Bits 
VALUES (NULL,1,0,NULL,1,NULL,0,1,NULL,1);

DELETE FROM dbo.Bits

-- SELECT * FROM dbo.Bits

/*********************************************************/
--N. Dynamic table creation + Random data INSERT + SELECT + DELETE

BEGIN
	DECLARE @SQL NVARCHAR(MAX);
	DECLARE @TableName NVARCHAR(50) = 'dbo.DynamicTestTable';
	DECLARE @ColumnCount INT = ABS(CHECKSUM(NEWID()) % 20) + 1; -- Random number of columns (1 to 20)
	DECLARE @ColumnDefinitions NVARCHAR(MAX) = '';
	DECLARE @InsertColumns NVARCHAR(MAX) = '';
	DECLARE @InsertValues NVARCHAR(MAX) = '';
	DECLARE @DataType NVARCHAR(50);
	DECLARE @ColumnName NVARCHAR(50);
	DECLARE @Counter INT = 1;
	DECLARE @Rand NVARCHAR(50);

	-- Drop the table if it already exists
	SET @SQL = 'DROP TABLE IF EXISTS ' + @TableName + ';';
	EXEC sp_executesql @SQL;

	-- Generate random columns with random data types
	WHILE @Counter <= @ColumnCount
	BEGIN
		SET @ColumnName = 'Col' + CAST(@Counter AS NVARCHAR);
		SET @Rand = ABS(CHECKSUM(NEWID()) % 17)
    
		-- Randomly select a data type (excluding BLOB types)
		SET @DataType = CASE @Rand
			WHEN 0 THEN 'TINYINT'
			WHEN 1 THEN 'SMALLINT'
			WHEN 2 THEN 'INT'
			WHEN 3 THEN 'BIGINT'
			WHEN 4 THEN 'BIT'
			WHEN 5 THEN 'DECIMAL(10, 2)'
			WHEN 6 THEN 'NUMERIC(10, 2)'
			WHEN 7 THEN 'FLOAT'
			WHEN 8 THEN 'REAL'
			WHEN 9 THEN 'CHAR(10)'
			WHEN 10 THEN 'VARCHAR(50)'
			WHEN 11 THEN 'NCHAR(10)'
			WHEN 12 THEN 'NVARCHAR(50)'
			WHEN 13 THEN 'DATE'
			WHEN 14 THEN 'TIME'
			WHEN 15 THEN 'DATETIME'
			WHEN 16 THEN 'UNIQUEIDENTIFIER'
		END;


		-- Append column definition
		SET @ColumnDefinitions = CONCAT(@ColumnDefinitions,@ColumnName,' ',@DataType,', ');
    
		-- Append column name and random value for insertion
		SET @InsertColumns = CONCAT(@InsertColumns, @ColumnName, ', ');

		SET @InsertValues = CONCAT(@InsertValues,  
			CASE @DataType
				WHEN 'TINYINT' THEN CAST(ABS(CHECKSUM(NEWID()) % 256) AS NVARCHAR(MAX))
				WHEN 'SMALLINT' THEN CAST(ABS(CHECKSUM(NEWID()) % 32768) AS NVARCHAR(MAX))
				WHEN 'INT' THEN CAST(ABS(CHECKSUM(NEWID())) AS NVARCHAR(MAX))
				WHEN 'BIGINT' THEN CAST(ABS(CAST(CHECKSUM(NEWID()) AS BIGINT) * 1000) AS NVARCHAR(MAX)) -- Use BIGINT for large values
				WHEN 'BIT' THEN CAST(ABS(CHECKSUM(NEWID()) % 2) AS NVARCHAR(MAX))
				WHEN 'DECIMAL(10, 2)' THEN CAST(ROUND(RAND() * 1000, 2) AS NVARCHAR(MAX))
				WHEN 'NUMERIC(10, 2)' THEN CAST(ROUND(RAND() * 1000, 2) AS NVARCHAR(MAX))
				WHEN 'FLOAT' THEN CAST(RAND() * 1000 AS NVARCHAR(MAX))
				WHEN 'REAL' THEN CAST(CAST(RAND() * 1000 AS REAL) AS NVARCHAR(MAX))
				WHEN 'CHAR(10)' THEN '''' + LEFT(NEWID(), 10) + ''''
				WHEN 'VARCHAR(50)' THEN '''' + CAST(NEWID() AS NVARCHAR(MAX)) + ''''
				WHEN 'NCHAR(10)' THEN '''' + LEFT(NEWID(), 10) + ''''
				WHEN 'NVARCHAR(50)' THEN '''' + CAST(NEWID() AS NVARCHAR(MAX)) + ''''
				WHEN 'DATE' THEN '''' + CAST(DATEADD(DAY, ABS(CHECKSUM(NEWID()) % 365), '2020-01-01') AS NVARCHAR(MAX)) + ''''
				WHEN 'TIME' THEN '''' + CAST(CAST(GETDATE() AS TIME) AS NVARCHAR(MAX)) + ''''
				WHEN 'DATETIME' THEN '''' + CAST(GETDATE() AS NVARCHAR(MAX)) + ''''
				WHEN 'UNIQUEIDENTIFIER' THEN '''' + CAST(NEWID() AS NVARCHAR(MAX)) + ''''
			END, ', ');
    
		SET @Counter = @Counter + 1;
	END;

	-- Remove trailing commas
	SET @ColumnDefinitions = LEFT(@ColumnDefinitions, LEN(@ColumnDefinitions) - 1);
	SET @InsertColumns = LEFT(@InsertColumns, LEN(@InsertColumns) - 1);
	SET @InsertValues = LEFT(@InsertValues, LEN(@InsertValues) - 1);

	-- Create the table
	SET @SQL = CONCAT('CREATE TABLE ', @TableName, ' (', @ColumnDefinitions, ');');
	PRINT @SQL
	EXEC sp_executesql @SQL;

	-- Insert one row of random data
	SET @SQL = CONCAT('INSERT INTO ', @TableName, ' (', @InsertColumns, ') VALUES (', @InsertValues,');');
	EXEC sp_executesql @SQL;


	-- Verify the inserted data
	SET @SQL = 'SELECT * FROM ' + @TableName + ';';
	EXEC sp_executesql @SQL;

	-- Delete
	SET @SQL = 'DELETE FROM ' + @TableName + ';';
	EXEC sp_executesql @SQL;
END


/*********************************************************/
--N+1. The same with K rows

BEGIN
	DECLARE 
		@N INT = ABS(CHECKSUM(NEWID())) % 20 + 1, -- random number of columns (1..20)
		@K INT = ABS(CHECKSUM(NEWID())) % 800 + 1, -- random row count 
		@TableName SYSNAME = 'DynamicTestTable',
		@sql NVARCHAR(MAX) = N'',
		@colDefs NVARCHAR(MAX) = N'',
		@insertCols NVARCHAR(MAX) = N'',
		@insertVals NVARCHAR(MAX) = N'',
		@i INT = 1;

	-- Available random data types
	DECLARE @types TABLE (TypeName NVARCHAR(50));
	INSERT INTO @types VALUES
	('INT'), ('BIGINT'), ('SMALLINT'), ('TINYINT'), 
	('BIT'), --('UNIQUEIDENTIFIER'),
	('CHAR(5)'), ('CHAR(10)'), ('VARCHAR(20)'), ('VARCHAR(50)'),
	('DATE'), ('DATETIME'), ('TIME'),
	('DECIMAL(10,2)'), ('DECIMAL(8,3)'),
	('FLOAT'), ('REAL');

	--SELECT @K

	-- Drop the table if it already exists
	SET @SQL = 'DROP TABLE IF EXISTS ' + @TableName + ';';
	EXEC sp_executesql @SQL;

	-- Generate random columns
	WHILE @i <= @N
	BEGIN
		DECLARE @type NVARCHAR(50);
		SELECT TOP 1 @type = TypeName FROM @types ORDER BY NEWID();

		SET @colDefs += CASE WHEN @i > 1 THEN ',' ELSE '' END 
			+ QUOTENAME('Col' + CAST(@i AS VARCHAR(10))) + ' ' + @type + ' NULL';

		SET @insertCols += CASE WHEN @i > 1 THEN ',' ELSE '' END 
			+ QUOTENAME('Col' + CAST(@i AS VARCHAR(10)));

		-- Generate random values depending on type
		SET @insertVals += CASE 
			WHEN @type LIKE 'TINYINT' THEN 
				CASE WHEN @i > 1 THEN ',' ELSE '' END + 'ABS(CHECKSUM(NEWID()) % 256)'
			WHEN @type LIKE 'SMALLINT' THEN 
				CASE WHEN @i > 1 THEN ',' ELSE '' END + 'ABS(CHECKSUM(NEWID()) % 32768)'
			WHEN @type LIKE 'INT' THEN 
				CASE WHEN @i > 1 THEN ',' ELSE '' END + 'ABS(CHECKSUM(NEWID()))'
			WHEN @type LIKE 'BIGINT' THEN 
				CASE WHEN @i > 1 THEN ',' ELSE '' END + 'ABS(CHECKSUM(NEWID())) % 1000000'
			WHEN @type LIKE 'BIT' THEN 
				CASE WHEN @i > 1 THEN ',' ELSE '' END + 'ABS(CHECKSUM(NEWID())) % 2'
			WHEN @type LIKE 'CHAR(5)' THEN 
				CASE WHEN @i > 1 THEN ',' ELSE '' END + 'LEFT(CONVERT(VARCHAR(36), NEWID()), 5)'
			WHEN @type LIKE 'CHAR(10)' THEN 
				CASE WHEN @i > 1 THEN ',' ELSE '' END + 'LEFT(CONVERT(VARCHAR(36), NEWID()), 10)'
			WHEN @type LIKE 'VARCHAR(20)' THEN 
				CASE WHEN @i > 1 THEN ',' ELSE '' END + 'LEFT(CONVERT(VARCHAR(36), NEWID()), 20)'
			WHEN @type LIKE 'VARCHAR(50)' THEN 
				CASE WHEN @i > 1 THEN ',' ELSE '' END + 'LEFT(CONVERT(VARCHAR(36), NEWID()), 50)'
			WHEN @type LIKE 'DATE' THEN 
				CASE WHEN @i > 1 THEN ',' ELSE '' END + 'DATEADD(DAY, ABS(CHECKSUM(NEWID())) % 3650, ''2000-01-01'')'
			WHEN @type LIKE 'DATETIME' THEN 
				CASE WHEN @i > 1 THEN ',' ELSE '' END + 'DATEADD(SECOND, ABS(CHECKSUM(NEWID())) % 31536000, ''2000-01-01'')'
			WHEN @type LIKE 'TIME' THEN 
				CASE WHEN @i > 1 THEN ',' ELSE '' END + 'DATEADD(MILLISECOND, ABS(CHECKSUM(NEWID())) % 31536000, ''00:00:00'')'
			WHEN @type LIKE 'DECIMAL(10,2)' THEN 
				CASE WHEN @i > 1 THEN ',' ELSE '' END + 'CAST(ABS(CHECKSUM(NEWID())) % 100000 / 100.0 AS DECIMAL(10,2))'
			WHEN @type LIKE 'DECIMAL(8,3)' THEN 
				CASE WHEN @i > 1 THEN ',' ELSE '' END + 'CAST(ABS(CHECKSUM(NEWID())) % 10000 / 1000.0 AS DECIMAL(8,3))'
			WHEN @type LIKE 'FLOAT' THEN 
				CASE WHEN @i > 1 THEN ',' ELSE '' END + 'ABS(CAST(CAST(NEWID() AS VARBINARY) AS BIGINT) % 100000) / 100.0'
			WHEN @type LIKE 'REAL' THEN 
				CASE WHEN @i > 1 THEN ',' ELSE '' END + 'CAST(ABS(CAST(CAST(NEWID() AS VARBINARY) AS BIGINT) % 100000) / 1000.0 AS REAL)'
		END;

		SET @i += 1;
	END

	-- Build CREATE TABLE
	SET @sql = CONCAT('CREATE TABLE ', QUOTENAME(@TableName), ' (', @colDefs ,');');
	PRINT @sql;
	EXEC sp_executesql @SQL;

	-- Insert rows
	SET @sql = CONCAT('INSERT INTO ', QUOTENAME(@TableName), ' (', @insertCols, ')
	SELECT ',@insertVals, '
	FROM (SELECT TOP (', CAST(@K AS VARCHAR(10)), ') ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) n 
		  FROM sys.objects a CROSS JOIN sys.objects b) t;');
	EXEC sp_executesql @SQL;


	-- Verify the inserted data
	SET @SQL = 'SELECT * FROM ' + @TableName + ';';
	EXEC sp_executesql @SQL;

	-- Delete
	SET @SQL = 'DELETE FROM ' + @TableName + ';';
	EXEC sp_executesql @SQL;
END