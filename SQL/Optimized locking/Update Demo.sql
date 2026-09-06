SELECT
    name,
    compatibility_level,
    is_accelerated_database_recovery_on,
    is_read_committed_snapshot_on,
    is_optimized_locking_on
FROM sys.databases
WHERE name = DB_NAME();

--ALTER DATABASE AdventureWorks_EXT SET COMPATIBILITY_LEVEL = 170


ALTER DATABASE AdventureWorks_EXT
SET OPTIMIZED_LOCKING = ON;

/****************************/

DROP TABLE IF EXISTS dbo.TestOrders;
GO

CREATE TABLE dbo.TestOrders
(
    OrderID     int NOT NULL
        CONSTRAINT PK_TestOrders PRIMARY KEY,
    CustomerID  int NOT NULL,
    Status      varchar(20) NOT NULL,
    Amount      decimal(12,2) NOT NULL
);
GO

INSERT INTO dbo.TestOrders
(
    OrderID,
    CustomerID,
    Status,
    Amount
)
SELECT
    n,
    n % 10,
    'NEW',
    100.00
FROM
(
    SELECT TOP (100)
        ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
    FROM sys.all_objects a
    CROSS JOIN sys.all_objects b
) x;
GO

/****************************/

BEGIN TRANSACTION;

    UPDATE dbo.TestOrders
    SET Status = 'PROCESSED'
    where OrderId % 50 = 0

ROLLBACK;


select object_id('dbo.TestOrders')


select * from dbo.TestOrders
where OrderId % 50 = 0