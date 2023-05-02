/*
	This script will generate a resultset of all permissions on a given database (the one on which context it runs) 
	and generate the t-sql commands in case it needs to be re issued later.
*/

SELECT  
		DB_NAME()
	,  princ.type_desc								  as 'member_description'
	, princ.name									  as 'member_principal_name' 
    , LOWER(STRING_AGG(perm.[permission_name], ', ')) COLLATE SQL_Latin1_General_CP1_CI_AS as 'db_permissions'
	, A.role_principal_name							  as 'role_assigned'
	, perm.state_desc								  as 'state_desc'
	, perm.class_desc								  as 'object_type'
	, obj.[type_desc]								  AS 'obj_type_desc'
	, COALESCE(s.name, SCHEMA_NAME(obj.schema_id))	  as 'schema_name'
    , OBJECT_NAME(perm.major_id)					  as 'object_name'
    , col.[name]									  as 'column_name'
	, CASE
		WHEN	a.role_principal_name IS NOT NULL 
		THEN 'ALTER ROLE ['+a.role_principal_name+'] ADD MEMBER ['+princ.name+']'
		WHEN	a.role_principal_name IS NULL 
			AND perm.class_desc = 'SCHEMA' 
			AND perm.state_desc = 'GRANT'
		THEN 'GRANT '+UPPER(STRING_AGG(perm.[permission_name], ', ')) COLLATE SQL_Latin1_General_CP1_CI_AS+' ON SCHEMA :: '+COALESCE(s.name, SCHEMA_NAME(obj.schema_id))+' TO '+princ.name
		WHEN	a.role_principal_name IS NULL 
			AND perm.class_desc = 'OBJECT_OR_COLUMN' 
			AND perm.state_desc = 'GRANT'
		THEN 'GRANT '+UPPER(STRING_AGG(perm.[permission_name], ', ')) COLLATE SQL_Latin1_General_CP1_CI_AS+' ON ['+COALESCE(s.name, SCHEMA_NAME(obj.schema_id))+'].['+OBJECT_NAME(perm.major_id)+'] TO ['+princ.name+']'
		WHEN	a.role_principal_name IS NULL 
			AND perm.class_desc = 'OBJECT_OR_COLUMN' 
			AND perm.state_desc = 'DENY'
		THEN 'DENY '+UPPER(STRING_AGG(perm.[permission_name], ', ')) COLLATE SQL_Latin1_General_CP1_CI_AS+' ON ['+COALESCE(s.name, SCHEMA_NAME(obj.schema_id))+'].['+OBJECT_NAME(perm.major_id)+'] TO ['+princ.name+']'
		WHEN	a.role_principal_name IS NULL 
			AND perm.class_desc = 'DATABASE'
			AND s.name IS NULL
            AND OBJECT_NAME(perm.major_id) IS NULL
			AND col.[name] IS NULL
			AND perm.state_desc = 'GRANT'
		THEN 'GRANT '+UPPER(STRING_AGG(perm.[permission_name], ', ')) COLLATE SQL_Latin1_General_CP1_CI_AS+' TO ['+princ.name+']'
	  END AS 'command'
FROM sys.database_principals princ  
	LEFT JOIN sys.database_permissions perm ON perm.[grantee_principal_id] = princ.[principal_id]
	LEFT JOIN sys.schemas s					ON s.schema_id = perm.major_id
	LEFT JOIN sys.columns col				ON col.[object_id] = perm.major_id AND col.[column_id] = perm.[minor_id]
	LEFT JOIN sys.objects obj				ON perm.major_id = obj.object_id
	--// query below gets the roles the users are assigned to
	LEFT JOIN (		SELECT m.type_desc	as member_description
						 , m.name		AS member_principal_name
						 , STRING_AGG(r.name, ', ') AS role_principal_name
					FROM    sys.database_role_members rm
					RIGHT JOIN    sys.database_principals   AS r  ON rm.role_principal_id      = r.principal_id
					RIGHT JOIN    sys.database_principals   AS m  ON rm.member_principal_id    = m.principal_id
					WHERE m.principal_id > 4
					AND m.type IN ('E','S','X')
					GROUP BY m.name, m.type_desc
				) A ON princ.name collate SQL_Latin1_General_CP1_CI_AS = A.member_principal_name
WHERE princ.[type] IN ('E','S','X')
  and princ.principal_id > 4
  --AND princ.name IN ('aws_rev')
group by  princ.type_desc
		, princ.name
		, a.role_principal_name
		, s.name
		, obj.schema_id
		, col.[name]
		, perm.major_id
		, perm.class_desc
		, perm.state_desc
		,obj.[type_desc]
