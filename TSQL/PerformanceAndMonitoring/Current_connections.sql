
SELECT 
    s.session_id,
    DB_NAME(s.database_id) AS [database_name],
    s.login_name,
    s.original_login_name,
    s.host_name,
    c.client_net_address,
    s.program_name,
    s.status AS [session_status],
    r.status AS [request_status],
    r.command,
    r.blocking_session_id,
    r.wait_type,
    r.wait_time AS [wait_time_ms],
    s.cpu_time AS [cpu_time_ms],
    (s.memory_usage * 8) AS [memory_usage_kb],
    s.open_transaction_count,
    s.login_time,
    r.start_time AS [request_start_time],
    -- Current running statement or last executed query text
    CASE 
        WHEN r.sql_handle IS NOT NULL THEN 
            SUBSTRING(
                qt.text, 
                (r.statement_start_offset / 2) + 1,
                ((CASE r.statement_end_offset 
                    WHEN -1 THEN DATALENGTH(qt.text)
                    ELSE r.statement_end_offset 
                  END - r.statement_start_offset) / 2) + 1
            )
        ELSE last_qt.text
    END AS [sql_text]
FROM sys.dm_exec_sessions s
LEFT JOIN sys.dm_exec_connections c 
    ON s.session_id = c.session_id
LEFT JOIN sys.dm_exec_requests r 
    ON s.session_id = r.session_id
OUTER APPLY sys.dm_exec_sql_text(r.sql_handle) qt
OUTER APPLY sys.dm_exec_sql_text(c.most_recent_sql_handle) last_qt
WHERE s.is_user_process = 1
  -- AND s.database_id = DB_ID('YourDatabaseName') -- Uncomment to filter by specific database
  -- AND s.session_id <> @@SPID                     -- Uncomment to exclude your own current query
ORDER BY s.session_id;
