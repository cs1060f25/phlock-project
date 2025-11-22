-- Verify that all indexes were created on the shares table
SELECT
    schemaname,
    tablename,
    indexname,
    indexdef
FROM pg_indexes
WHERE tablename = 'shares'
  AND schemaname = 'public'
ORDER BY indexname;
