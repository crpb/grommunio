-- FOLDER PERMISSIONS LOOKUP TABLE
CREATE TABLE IF NOT EXISTS "temp"."perms" (
	"perm"	INTEGER UNIQUE,
	"name"	TEXT
);
INSERT OR REPLACE INTO perms("perm","name") VALUES
( 1,'redany'),
( 2,'create'),
( 4,'sendas'),
( 8,'editowned'),
( 16,'deleteowned'),
( 32,'editany'),
( 64,'deleteany'),
( 128,'createsubfolder'),
( 256,'folderowner'),
( 512,'foldercontact'),
( 1024,'foldervisible'),
( 2048,'freebusysimple'),
( 4096,'freebusydetailed'),
( 8192,'storeowner')
;
-- FOLDER LOOKUP VIEW
CREATE VIEW IF NOT EXISTS "temp"."folderlist"
AS SELECT
	distinct(p.folder_id),
    f1.propval
  FROM permissions p
 INNER JOIN folder_properties f1
    ON f1.folder_id = p.folder_id
   AND f1.proptag = 805371935
 ORDER BY p.folder_id
;
-- LOOKUP PERMISSIONS
  SELECT p.folder_id as folder_int,
         (SELECT printf('0x%x',p.folder_id)) AS folder_hex,
         f.propval AS folder_name,
         p.username,
         (SELECT printf('0x%x',p.permission)) AS permission_hex,
         x.name as permission
    FROM permissions p
    JOIN folderlist f
      ON p.folder_id = f.folder_id
    LEFT JOIN temp.perms x
      ON x.perm = p.permission
ORDER BY p.folder_id ASC,
         p.username ASC
;
