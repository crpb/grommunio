/*  
  select  m.message_id
  FROM messages m
 INNER JOIN folder_properties f
    ON f.folder_id = m.parent_fid
   AND f.proptag = 907214879
   AND f.propval in ('IPF.Appointment','IPF.Journal','IPF.StickyNote','IPF.Task','IPF.Contact')
 INNER JOIN message_properties mp1
    ON mp1.message_id = m.message_id
   AND mp1.proptag = 1703967
   AND mp1.propval in ('IPM.Appointment','IPM.Activity','IPM.StickyNote','IPM.Task','IPM.Contact')
 INNER JOIN folder_properties f2
    ON f2.folder_id = m.parent_fid
   AND f2.proptag = 80537193
 ORDER BY m.message_id ASC;
*/

select mp1.propval AS foldertype, f.propval AS foldername, m.message_id
from messages m
inner join folder_properties f on f.folder_id = m.parent_fid and f.proptag = 907214879
--     and f.propval in ('IPF.Appointment','IPF.Journal','IPF.StickyNote','IPF.Task','IPF.Contact')
inner join message_properties mp1 on mp1.message_id = m.message_id and mp1.proptag = 1703967
--     and mp1.propval in ('IPM.Appointment','IPM.Activity','IPM.StickyNote','IPM.Task','IPM.Contact')
inner join folder_properties f2 on f2.folder_id = m.parent_fid and f2.proptag = 805371935
-- where 1=1
-- and ('IPM.StickyNote' = 'all' or mp1.propval = 'IPM.StickyNote')
and m.parent_fid not in (11,14,23,1,5)
-- AND m.parent_fid not in (SELECT folder_id WHERE foldername = "GS-SyncState" AND m.parent_fid = 1)
order by m.message_id asc;

--  1703967

/*
SELECT
	DISTINCT(fld.folder_id) AS id,
	fld.parent_id AS pid,
	fldprops.propval,
	fldprops.proptag
FROM
	folders fld
JOIN
	folder_properties fldprops
ON
	fld.folder_id = fldprops.folder_id
JOIN
	folders fldp
ON
	fld.parent_id = fldp.folder_id
WHERE
	(fldprops.proptag = 907214879 AND fldprops.propval LIKE 'IPF.%' AND fld.parent_id > 8)
GROUP BY
	fld.folder_id,
	fldp.folder_id
;

*/


/*
CREATE VIEW IF NOT EXISTS folderlist
AS SELECT distinct(p.folder_id),
          p.parent_id,
          f1.propval AS foldername
     FROM folders p
     JOIN folder_properties f1
       ON f1.folder_id = p.folder_id
      AND f1.proptag = 805371935
    ORDER BY p.folder_id
;
*/



/*
-- MSGs/FOLDER
-- DROP VIEW IF EXISTS messagecount;
CREATE VIEW IF NOT EXISTS messagecount AS
SELECT fl.folder_id AS id,
       fl.foldername AS folder,
       count(m.message_id) AS count
  FROM folderlist fl
  LEFT JOIN messages m
    ON fl.folder_id = m.parent_fid
   AND m.is_deleted = 0
 WHERE fl.parent_id > 1
 GROUP BY fl.folder_id,
          fl.foldername
;

-- DROP VIEW IF EXISTS folderstatistics;
CREATE VIEW IF NOT EXISTS folderstatistics AS
SELECT fl.folder_id AS id,
       fl.foldername AS name,
       SUM(m.message_size) as foldersize,
       count(m.message_id) AS count
  FROM folderlist fl
  LEFT JOIN messages m
    ON fl.folder_id = m.parent_fid
   AND m.is_deleted = 0
 WHERE fl.parent_id > 1
 GROUP BY fl.folder_id,
          fl.foldername;
