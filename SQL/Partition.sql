-- Check current situation with partitions and RequestsIds
DECLARE
  @IntMinValue INT = -2147483648,
  @IntMaxValue INT = 2147483647

;WITH CTE AS
(
  SELECT
    pf.name as PartitionFunction
    ,LAG(prv.value, 1, -2147483648) OVER (PARTITION BY pf.name ORDER BY prv.value) AS LeftBorder
    ,prv.value AS RightBorder
    ,prv.boundary_id AS PartitionNumber
    ,CONVERT(BIT, CASE WHEN pf.boundary_value_on_right = 0 THEN 0 ELSE 1 END) AS IncludeLeftBorder
    ,CONVERT(BIT, CASE WHEN pf.boundary_value_on_right = 0 THEN 1 ELSE 0 END) AS IncludeRightBorder
  FROM sys.partition_functions pf 
  INNER JOIN sys.partition_range_values prv ON prv.function_id = pf.function_id
)

,CTE_Complete AS (
  SELECT
    PartitionFunction,
    LeftBorder,
    RightBorder,
    PartitionNumber,
    IncludeLeftBorder,
    IncludeRightBorder
  FROM CTE
  UNION ALL
  -- last partition
  SELECT
    PartitionFunction,
    MAX(CTE.RightBorder) AS LeftBorder,
    @IntMaxValue AS RightBorder,
    MAX(PartitionNumber) + 1 AS PartitionNumber,
    0 AS IncludeLeftBorder,
    1 AS IncludeRightBorder
  FROM CTE
  GROUP BY PartitionFunction
)

,base AS (
  SELECT
    c.PartitionFunction,
    c.LeftBorder,
    c.RightBorder,
    c.PartitionNumber
  FROM CTE_Complete c
)

,misaligned AS (
  SELECT
    b.PartitionNumber,
    COUNT(*)                      AS pf_rows_at_border,
    COUNT(DISTINCT b.LeftBorder)  AS pn_distinct
  FROM base b
  GROUP BY b.PartitionNumber
)

SELECT * FROM base
WHERE 1=1
  AND base.PartitionFunction = 'PF_Date'
  AND base.LeftBorder >= '2013-01-01 00:00:00.000'
  AND base.PartitionNumber = (
    SELECT TOP 1 m.PartitionNumber
    FROM misaligned m
    WHERE m.pn_distinct > 1
    ORDER BY m.PartitionNumber ASC
  ) - 1  -- GET First PartitionNumber where RequestsIds are not aligned across PFs
ORDER BY base.LeftBorder
