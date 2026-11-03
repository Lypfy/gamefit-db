ALTER TABLE User_pc ENABLE TRIGGER trg_UserPC_InsteadOfDelete;

SELECT pc_id, pc_name, is_deleted 
FROM User_pc
WHERE pc_id = 19;

DELETE FROM User_pc WHERE pc_id = 19;

SELECT r.recommendation_id, p.pc_id, p.pc_name, p.is_deleted, r.status 
FROM Game_PC_Recommendation r
JOIN User_pc p ON r.pc_id = p.pc_id
WHERE r.pc_id = 19;

UPDATE User_pc
SET is_deleted = 0
WHERE pc_id = 19;