-- FOLDER PERMISSIONS LOOKUP TABLE
CREATE TABLE IF NOT EXISTS "temp"."perms" (
  "perm"  INTEGER UNIQUE,
  "name"  TEXT
);
INSERT OR REPLACE INTO temp.perms("perm","name") VALUES
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
( 8192,'storeowner'),
( 1025,'reviewer:readany,foldervisible'),
( 1026,'contributor:create,foldervisible'),
( 1043,'noneditingauthor:readany,create,deleteowned,foldervisible'),
( 1051,'author:readany,create,editowned,deleteowned,foldervisible'),
( 1147,'editor:readany,create,editowned,deleteowned,editany,deleteany,foldervisible'),
( 1179,'publishingauthor:readany,create,editowned,deleteowned,createsubfolder,foldervisible'),
( 1275,'publishingeditor:readany,create,editowned,deleteowned,editany,deleteany,createsubfolder,foldervisible'),
( 7195,'calendar-author:readany,create,editowned,deleteowned,foldervisible'),
( 7323,'calendar-publishingauthor:readany,create,editowned,deleteowned,createsubfolder,foldervisible')
;
-- FOLDER LOOKUP VIEW VIA FOLDERS INCLUDING PARENT
CREATE VIEW IF NOT EXISTS temp.folderlist
AS SELECT distinct(p.folder_id),
          p.parent_id,
          f1.propval
     FROM folders p
     JOIN folder_properties f1
       ON f1.folder_id = p.folder_id
      AND f1.proptag = 805371935
    ORDER BY p.folder_id
;
-- FOLDER LOOKUP VIEW VIA PERMISSIONS
CREATE VIEW IF NOT EXISTS temp.folderlist_p
AS SELECT distinct(p.folder_id),
          f1.propval
  FROM    permissions p
 INNER    JOIN folder_properties f1
    ON    f1.folder_id = p.folder_id
   AND    f1.proptag = 805371935
 ORDER    BY p.folder_id
;
-- LOOKUP PERMISSIONS
CREATE VIEW IF NOT EXISTS temp.folderpermissions
AS SELECT p.folder_id as folder_id,
          f.parent_id,
          (SELECT printf('0x%x',p.folder_id)) AS folder_hex,
          (SELECT printf('0x%x',f.parent_id)) AS parent_hex,
          f.propval AS folder_name,
          p.username,
          x.name as permission,
          p.permission AS permission_dec,
          (SELECT printf('0x%x',p.permission)) AS permission_hex
    FROM  permissions p
    JOIN  folderlist f
      ON  p.folder_id = f.folder_id
    LEFT  JOIN temp.perms x
      ON  x.perm = p.permission
ORDER BY  p.folder_id ASC,
          f.parent_id ASC,
          p.username ASC
;
-- QUERY OUR VIEW
SELECT * FROM folderpermissions
;

