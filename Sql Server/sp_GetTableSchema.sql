
CREATE PROCEDURE dbo.sp_GetTableSchema
	@Database VARCHAR(50)
	, @TableName VARCHAR(100)
AS
BEGIN

	DECLARE @Sql VARCHAR(MAX)
	
	SET @Sql =	
		'SELECT 
			  TableCatalog = TABLE_CATALOG
			  , TableSchema = TABLE_SCHEMA
			  , TableName =TABLE_NAME
			  , Position = ORDINAL_POSITION
			  , ColumnName = COLUMN_NAME
			  , DataType = DATA_TYPE
			  , Length = CHARACTER_MAXIMUM_LENGTH
			  , Nullable = IS_NULLABLE
			  , ColumnDefault = COLUMN_DEFAULT
			  , Precision = NUMERIC_PRECISION
			  , Scale = NUMERIC_SCALE
		FROM ' + @Database + '.INFORMATION_SCHEMA.COLUMNS 
		WHERE TABLE_NAME = ''' + @TableName + '''' +
		' ORDER BY ORDINAL_POSITION ASC'

	--SELECT @Sql
	EXEC (@Sql)
END
GO