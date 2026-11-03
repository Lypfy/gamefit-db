INSERT INTO Games (name) 
VALUES (N'Trigger Test Game');
DECLARE @TestGameId INT = SCOPE_IDENTITY();

INSERT INTO Tags (name, is_hidden) 
VALUES (N'Trigger Tag Test', 0)
DECLARE @TestTagId INT = SCOPE_IDENTITY();

INSERT INTO Games_Tags (game_id, tag_id)
VALUES (@TestGameId, @TestTagId);

PRINT N'Game ID: ' + CAST(@TestGameId AS VARCHAR(10)) + N', Tag ID: ' + CAST(@TestTagId AS VARCHAR(10));

SELECT * FROM Tags WHERE name =	N'Trigger Tag Test';

SELECT g.game_id, g.name, t.tag_id, t.name, t.is_hidden FROM Games_Tags gt 
JOIN Tags t ON gt.tag_id = t.tag_id
JOIN Games g ON g.game_id = gt.game_id
WHERE t.name =	N'Trigger Tag Test' AND g.name = N'Trigger Test Game';

DELETE FROM Tags WHERE tag_id = 81;

-- BƯỚC 1: Xóa bảng con trung gian (Games_Tags) trước để không bị dính khóa ngoại
DELETE FROM Games_Tags 
WHERE tag_id IN (SELECT tag_id FROM Tags WHERE name = N'Trigger Tag Test');
-- BƯỚC 2: Xóa bản ghi trong bảng Tags
-- (Phải tạm tắt trigger xóa mềm thì mới xóa vĩnh viễn khỏi CSDL được)
ALTER TABLE Tags DISABLE TRIGGER trg_Tags_InsteadOfDelete;
DELETE FROM Tags WHERE name = N'Trigger Tag Test';
ALTER TABLE Tags ENABLE TRIGGER trg_Tags_InsteadOfDelete; -- Bật lại trigger
-- BƯỚC 3: Xóa bản ghi trong bảng Games
-- (Tạm tắt trigger xóa mềm của Games nếu có để xóa cứng)
ALTER TABLE Games DISABLE TRIGGER trg_Games_SoftDelete;
DELETE FROM Games WHERE name = N'Trigger Test Game';
ALTER TABLE Games ENABLE TRIGGER trg_Games_SoftDelete; -- Bật lại trigger
GO
-- KIỂM TRA LẠI: Kết quả trả về 0 dòng là đã sạch sẽ hoàn toàn!
SELECT * FROM Tags WHERE name = N'Trigger Tag Test';
SELECT * FROM Games WHERE name = N'Trigger Test Game';