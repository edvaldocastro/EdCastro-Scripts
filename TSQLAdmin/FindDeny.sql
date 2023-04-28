-- Find Deny in SQL Server
SELECT l.name as grantee_name, p.state_desc, p.permission_name, o.name
FROM sys.database_permissions AS p JOIN sys.database_principals AS l 
ON   p.grantee_principal_id = l.principal_id
JOIN sys.sysobjects O 
ON p.major_id = O.id 
WHERE p.state_desc ='DENY'
