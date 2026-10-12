/*  - MUC LUC
        + GamePCRec
        + GameRequirement
        + Games 
        + Tags
        + User_pc
        + Reviews
        + Wishlist
*/

-- GamePCRec
CREATE OR ALTER TRIGGER trg_GamePCRec_InsteadOfDelete
ON Game_PC_Recommendation
INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Thay vì xóa cứng, ta Update is_hidden = 1 cho các dòng bị xóa
    UPDATE G
    SET is_hidden = 1
    FROM Game_PC_Recommendation G
    JOIN deleted d ON G.recommendation_id = d.recommendation_id;
END
GO 

CREATE OR ALTER TRIGGER trg_GamePCRec_InsteadOfInsert
ON Game_PC_Recommendation
INSTEAD OF INSERT
AS
BEGIN
    SET NOCOUNT ON;
    
    -- 1. Xử lý trường hợp Update (Nếu bộ user_id, game_id, pc_id đã tồn tại)
    UPDATE G
    SET 
        G.is_hidden = 0,         -- Khôi phục lại bài nếu trước đó bị ẩn
        G.type = i.type,         -- Cập nhật loại cấu hình mới
        G.note = i.note,         -- Cập nhật ghi chú mới
        G.created_at = GETDATE() -- Reset lại ngày đăng
    FROM Game_PC_Recommendation G
    JOIN inserted i ON G.user_id = i.user_id 
                   AND G.game_id = i.game_id 
                   AND G.pc_id = i.pc_id;

    -- 2. Xử lý trường hợp Insert mới (Nếu bộ user_id, game_id, pc_id chưa tồn tại)
    INSERT INTO Game_PC_Recommendation (user_id, game_id, pc_id, type, note)
    SELECT i.user_id, i.game_id, i.pc_id, i.type, i.note
    FROM inserted i
    WHERE NOT EXISTS (
        SELECT 1 
        FROM Game_PC_Recommendation G 
        WHERE G.user_id = i.user_id 
          AND G.game_id = i.game_id 
          AND G.pc_id = i.pc_id
    );
END
GO 

-- GameRequirement
CREATE OR ALTER TRIGGER trg_GameRequirement_Check
ON Game_requirement
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON; -- Thêm dòng này

    IF EXISTS (
        SELECT 1
        FROM Game_requirement min_req
        JOIN inserted i ON min_req.game_id = i.game_id
        JOIN Game_requirement rec_req
            ON min_req.game_id = rec_req.game_id
           AND min_req.type = 'MINIMUM'
           AND rec_req.type = 'RECOMMENDED'

        JOIN Cpus min_cpu
            ON min_req.cpu_id = min_cpu.cpu_id
        JOIN Cpus rec_cpu
            ON rec_req.cpu_id = rec_cpu.cpu_id

        JOIN Gpus min_gpu
            ON min_req.gpu_id = min_gpu.gpu_id
        JOIN Gpus rec_gpu
            ON rec_req.gpu_id = rec_gpu.gpu_id

        WHERE rec_cpu.benchmark_score < min_cpu.benchmark_score
           OR rec_gpu.benchmark_score < min_gpu.benchmark_score
           OR rec_req.ram < min_req.ram
           OR rec_req.storage < min_req.storage
    )
    BEGIN
        RAISERROR(N'Cấu hình RECOMMENDED phải lớn hơn hoặc bằng MINIMUM.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END
END;
GO


-- Games 
CREATE OR ALTER TRIGGER trg_Games_SoftDelete
ON Games
INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON;

    -- 1. Xóa mềm Game
    UPDATE Games
    SET is_active = 0
    WHERE game_id IN (
        SELECT game_id
        FROM deleted
    );

    -- 2. Ẩn tất cả đánh giá của Game
    UPDATE Reviews
    SET is_hidden = 1
    WHERE game_id IN (
        SELECT game_id
        FROM deleted
    );
END;
GO 

-- Tags
CREATE OR ALTER TRIGGER trg_Tags_InsteadOfDelete
ON Tags
INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE Tags
    SET is_hidden = 1
    WHERE tag_id IN (SELECT tag_id FROM deleted);
END;
GO

-- User_pc
CREATE OR ALTER TRIGGER trg_UserPC_InsteadOfDelete
ON User_pc
INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE User_pc
    SET is_deleted = 1
    WHERE pc_id IN (SELECT pc_id FROM deleted);
END;
GO


-- Reviews
CREATE OR ALTER TRIGGER trg_Reviews_Update 
ON Reviews 
AFTER UPDATE 
AS
BEGIN 
	IF EXISTS (
		SELECT 1 
		FROM inserted i 
		JOIN deleted d ON i.review_id = d.review_id 
		WHERE i.user_id <> d.user_id 
		OR i.game_id <> d.game_id 
		OR i.created_at <> d.created_at 
	) 
	BEGIN 
	RAISERROR (N'Các thông tin cập nhật không phù hợp', 16, 1) 
	ROLLBACK TRANSACTION 
	RETURN ;
	END 
END
GO 

-- Wishlist
CREATE OR ALTER TRIGGER trg_Wishlist_CheckGameStatus
ON Wishlist
INSTEAD OF INSERT
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (
        SELECT 1 
        FROM inserted i
        JOIN Games g ON i.game_id = g.game_id
        WHERE g.is_active = 0
    )
    BEGIN
        RAISERROR (N'Game này đã ngưng hoạt động, không thể thêm vào Danh sách yêu thích (Wishlist)!', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END
    INSERT INTO Wishlist (user_id, game_id)
    SELECT user_id, game_id
    FROM inserted;
END;