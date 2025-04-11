/*********************************************************/

--1. Fixed
CREATE TABLE dbo.Fixed
(
Col1 char(5) NOT NULL,
Col2 int NOT NULL,
Col3 char(3) NULL,
Col4 char(6) NOT NULL
);

INSERT dbo.Fixed VALUES ('ABCDE', 123, NULL, 'CCCC');

DELETE FROM dbo.Fixed


EXEC [dbo].[ResurrectionOfLostData]
	@SchemaTableName = 'dbo.Fixed'
	,@HasBlobData = 0
	,@IsDebugMode = 1



-- SELECT * FROM dbo.Fixed
/*********************************************************/

--2. Var
CREATE TABLE dbo.Variable
(
Col1 char(3) NOT NULL,
Col2 varchar(250) NOT NULL,
Col3 varchar(5) NULL,
Col4 varchar(20) NOT NULL,
Col5 smallint NULL
);
INSERT dbo.Variable VALUES
('AAA', REPLICATE('X', 250), NULL, 'ABC', 123);

DELETE FROM dbo.Variable

EXEC [dbo].[ResurrectionOfLostData]
	@SchemaTableName = 'dbo.Variable'
	,@HasBlobData = 0
	,@IsDebugMode = 1

/*********************************************************/
--Uncomment BLOB part of SP code

--3. Full
CREATE TABLE dbo.TestTable
(
[Col_image] image,
[Col_text] text,
[Col_uniqueidentifier] uniqueidentifier,
[Col_tinyint] tinyint,
[Col_smallint] smallint,
[Col_int] int,
[Col_smalldatetime] smalldatetime,
[Col_real] real,
[Col_money] money,
[Col_datetime] datetime,
[Col_float] float,
[Col_Int_sql_variant] sql_variant,
[Col_numeric_sql_variant] sql_variant,
[Col_varchar_sql_variant] sql_variant,
[Col_uniqueidentifier_sql_variant] sql_variant,
[Col_Date_sql_variant] sql_variant,
[Col_varbinary_sql_variant] sql_variant,
[Col_ntext] ntext,
[Col_bit] bit,
[Col_decimal] decimal(18,4),
[Col_numeric] numeric(18,4),
[Col_smallmoney] smallmoney,
[Col_bigint] bigint,
[Col_varbinary] varbinary(Max),
[Col_varchar] varchar(Max),
[Col_binary] binary(8),
[Col_char] char,
[Col_timestamp] timestamp,
[Col_nvarchar] nvarchar(Max),
[Col_nchar] nchar,
[Col_xml] xml,
[Col_sysname] sysname
)
 
GO
--Insert data into it
INSERT INTO [TestTable]
([Col_image]
,[Col_text]
,[Col_uniqueidentifier]
,[Col_tinyint]
,[Col_smallint]
,[Col_int]
,[Col_smalldatetime]
,[Col_real]
,[Col_money]
,[Col_datetime]
,[Col_float]
,[Col_Int_sql_variant]
,[Col_numeric_sql_variant]
,[Col_varchar_sql_variant]
,[Col_uniqueidentifier_sql_variant]
,[Col_Date_sql_variant]
,[Col_varbinary_sql_variant]
,[Col_ntext]
,[Col_bit]
,[Col_decimal]
,[Col_numeric]
,[Col_smallmoney]
,[Col_bigint]
,[Col_varbinary]
,[Col_varchar]
,[Col_binary]
,[Col_char]
,[Col_nvarchar]
,[Col_nchar]
,[Col_xml]
,[Col_sysname])
VALUES
(CONVERT(IMAGE,REPLICATE('A',4000))
,REPLICATE('B',8000)
,NEWID()
,10
,20
,3000
,GETDATE()
,4000
,5000
,getdate()+15
,66666.6666
,777777
,88888.8888
,REPLICATE('C',8000)
,newid()
,getdate()+30
,CONVERT(VARBINARY(8000),REPLICATE('D',8000))
,REPLICATE('E',4000)
,1
,99999.9999
,10101.1111
,1100
,123456
,CONVERT(VARBINARY(MAX),REPLICATE('F',8000))
,REPLICATE('G',8000)
,0x4646464
,'H'
,REPLICATE('I',4000)
,'J'
,CONVERT(XML,REPLICATE('K',4000))
,REPLICATE('L',100)
)

SELECT * FROM dbo.TestTable

DELETE FROM dbo.TestTable



DECLARE 
	@DBName NVARCHAR(50) =  DB_NAME()
	,@SchemaTableName NVARCHAR(100) = 'dbo.TestTable'
	,@DateFrom DATETIME = (SELECT CAST('2023-08-19' AS DATETIME))
	,@DateTo DATETIME = (SELECT CAST('2023-08-21' AS DATETIME))

EXEC [dbo].[RecoverDeletedData] @DBName, @SchemaTableName, @DateFrom, @DateTo
