-- =========================================================================================
-- MIGRATION SCRIPT: NÂNG CẤP TRANSACTIONS CHO CÁC STORED PROCEDURES QUAN TRỌNG TRONG GAMEFIT
-- Mục tiêu: Đảm bảo tính toàn vẹn dữ liệu (ACID) cho 5 Stored Procedures trọng yếu:
--   1. sp_updateGame (Games, Games_Tags)
--   2. sp_deleteGame (Games, Games_Tags, Game_requirement, Reviews, Wishlist, Game_PC_Recommendation)
--   3. sp_addGame (Games, Games_Tags)
--   4. sp_DeleteReview (Reviews, Votes, Review_Reports)
--   5. sp_DeleteComputerConfig (User_pc, Game_PC_Recommendation)
-- =========================================================================================

SET NOCOUNT ON;
PRINT N'Bắt đầu cập nhật Transactions cho các Stored Procedures...';
GO

-- -----------------------------------------------------------------------------------------
-- 1 & 3. sp_addGame (Thêm game mới + Tags trong 1 Transaction)
-- -----------------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_addGame(
    @name NVARCHAR(255), 
    @description NVARCHAR(MAX), 
    @publisher NVARCHAR(255), 
    @developer NVARCHAR(255), 
    @name_tag NVARCHAR(MAX),  
    @release_date DATETIME, 
    @download_url VARCHAR(500),
    @image NVARCHAR(MAX) = NULL
) 
AS
BEGIN  
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @game_id INT;

    BEGIN TRY
        BEGIN TRANSACTION;
        -- 1. Thêm game vào bảng Games
        INSERT INTO Games(name, description, publisher, developer, release_date, download_url, image) 
        VALUES (@name, @description, @publisher, @developer, @release_date, @download_url, @image);

        -- 2. Lấy ID game vừa tạo
        SET @game_id = SCOPE_IDENTITY();

        -- 3. Gán các tag cho game
        IF @name_tag IS NOT NULL AND LEN(TRIM(@name_tag)) > 0
        BEGIN
            -- Kiểm tra: Nếu tất cả tag truyền vào đều không tồn tại trong DB -> Báo lỗi để kích hoạt ROLLBACK
            IF NOT EXISTS (
                SELECT 1 FROM Tags t 
                INNER JOIN STRING_SPLIT(@name_tag, ',') s 
                    ON LOWER(LTRIM(RTRIM(s.value))) = LOWER(LTRIM(RTRIM(t.name)))
            )
            BEGIN
                RAISERROR(N'Thể loại game không hợp lệ hoặc không tồn tại trong hệ thống.', 16, 1);
            END;

            INSERT INTO Games_Tags(game_id, tag_id) 
            SELECT DISTINCT @game_id, t.tag_id 
            FROM Tags t
            INNER JOIN STRING_SPLIT(@name_tag, ',') s
                ON LOWER(LTRIM(RTRIM(s.value))) = LOWER(LTRIM(RTRIM(t.name)));
        END;
        COMMIT TRANSACTION;
        -- 4. Trả về ID game vừa tạo
        SELECT @game_id AS game_id;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@ErrMsg, 16, 1);
    END CATCH;
END;
GO
PRINT N'-> Đã cập nhật sp_addGame với Transaction thành công.';
GO

-- -----------------------------------------------------------------------------------------
-- 2. sp_updateGame (Cập nhật game + Tags trong 1 Transaction)
-- -----------------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_updateGame
    @game_id INT,
    @name NVARCHAR(255),
    @name_tag NVARCHAR(MAX),
    @developer NVARCHAR(255),
    @is_active BIT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NOT EXISTS (SELECT 1 FROM Games WHERE game_id = @game_id)
    BEGIN
        RAISERROR(N'Game không tồn tại trong hệ thống.', 16, 1);
        RETURN;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- 1. Cập nhật thông tin cơ bản của Game
        UPDATE Games
        SET name = @name,
            developer = @developer,
            is_active = @is_active
        WHERE game_id = @game_id;

        -- 2. Cập nhật danh sách Tags
        IF @name_tag IS NOT NULL
        BEGIN
            DELETE FROM Games_Tags WHERE game_id = @game_id;

            IF LEN(TRIM(@name_tag)) > 0
            BEGIN
                INSERT INTO Games_Tags (game_id, tag_id)
                SELECT DISTINCT @game_id, t.tag_id
                FROM Tags t
                INNER JOIN STRING_SPLIT(@name_tag, ',') s 
                    ON LOWER(LTRIM(RTRIM(s.value))) = LOWER(LTRIM(RTRIM(t.name)));
            END;
        END;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@ErrMsg, 16, 1);
    END CATCH;
END;
GO
PRINT N'-> Đã cập nhật sp_updateGame với Transaction thành công.';
GO

-- -----------------------------------------------------------------------------------------
-- 3. sp_deleteGame (Xóa game + các bảng liên kết trong 1 Transaction)
-- -----------------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_deleteGame
    @game_id INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NOT EXISTS (SELECT 1 FROM Games WHERE game_id = @game_id)
    BEGIN
        RAISERROR(N'Game không tồn tại trong hệ thống.', 16, 1);
        RETURN;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- 1. Dọn dẹp các lượt Vote của Đề xuất cấu hình liên quan đến game này
        IF EXISTS (SELECT 1 FROM sys.tables WHERE name = 'Votes') AND EXISTS (SELECT 1 FROM sys.tables WHERE name = 'Game_PC_Recommendation')
        BEGIN
            DELETE v
            FROM Votes v
            JOIN Game_PC_Recommendation gpr ON v.target_id = gpr.recommendation_id
            WHERE v.target_type = 'RECOMMENDATION' AND gpr.game_id = @game_id;
        END;

        -- 2. Xóa các đề xuất cấu hình của game này
        IF EXISTS (SELECT 1 FROM sys.tables WHERE name = 'Game_PC_Recommendation')
        BEGIN
            DELETE FROM Game_PC_Recommendation WHERE game_id = @game_id;
        END;

        -- 3. Dọn dẹp các lượt Vote & Báo cáo vi phạm của Đánh giá (Reviews) thuộc game này
        IF EXISTS (SELECT 1 FROM sys.tables WHERE name = 'Votes') AND EXISTS (SELECT 1 FROM sys.tables WHERE name = 'Reviews')
        BEGIN
            DELETE v
            FROM Votes v
            JOIN Reviews r ON v.target_id = r.review_id
            WHERE v.target_type = 'REVIEW' AND r.game_id = @game_id;
        END;

        IF EXISTS (SELECT 1 FROM sys.tables WHERE name = 'Review_Reports') AND EXISTS (SELECT 1 FROM sys.tables WHERE name = 'Reviews')
        BEGIN
            DELETE rr
            FROM Review_Reports rr
            JOIN Reviews r ON rr.review_id = r.review_id
            WHERE r.game_id = @game_id;
        END;

        -- 4. Xóa đánh giá game (Reviews)
        IF EXISTS (SELECT 1 FROM sys.tables WHERE name = 'Reviews')
        BEGIN
            DELETE FROM Reviews WHERE game_id = @game_id;
        END;

        -- 5. Xóa danh sách yêu thích liên quan đến game (Wishlist)
        IF EXISTS (SELECT 1 FROM sys.tables WHERE name = 'Wishlist')
        BEGIN
            DELETE FROM Wishlist WHERE game_id = @game_id;
        END;

        -- 6. Xóa các ràng buộc thể loại của game (Games_Tags)
        IF EXISTS (SELECT 1 FROM sys.tables WHERE name = 'Games_Tags')
        BEGIN
            DELETE FROM Games_Tags WHERE game_id = @game_id;
        END;

        -- 7. Xóa cấu hình yêu cầu phần cứng của game (Game_requirement)
        IF EXISTS (SELECT 1 FROM sys.tables WHERE name = 'Game_requirement')
        BEGIN
            DELETE FROM Game_requirement WHERE game_id = @game_id;
        END;

        -- 8. Xóa chính bản ghi Game (Nếu có trigger trg_Games_SoftDelete sẽ tự động chuyển is_active = 0, nếu không sẽ xóa cứng)
        DELETE FROM Games WHERE game_id = @game_id;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@ErrMsg, 16, 1);
    END CATCH;
END;
GO
PRINT N'-> Đã cập nhật sp_deleteGame với Transaction thành công.';
GO

-- -----------------------------------------------------------------------------------------
-- 4. sp_DeleteReview (Xóa đánh giá + Votes + Reports trong 1 Transaction)
-- -----------------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_DeleteReview
    @user_id INT,
    @game_id INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @review_id INT;
    SELECT @review_id = review_id 
    FROM Reviews 
    WHERE user_id = @user_id AND game_id = @game_id;

    IF @review_id IS NOT NULL
    BEGIN
        BEGIN TRY
            BEGIN TRANSACTION;

            -- 1. Xóa các lượt Vote của Review này (bảng Votes đa hình không có FK cascade)
            IF EXISTS (SELECT 1 FROM sys.tables WHERE name = 'Votes')
            BEGIN
                DELETE FROM Votes 
                WHERE target_type = 'REVIEW' AND target_id = @review_id;
            END;

            -- 2. Xóa các Báo cáo vi phạm của Review này
            IF EXISTS (SELECT 1 FROM sys.tables WHERE name = 'Review_Reports')
            BEGIN
                DELETE FROM Review_Reports 
                WHERE review_id = @review_id;
            END;

            -- 3. Xóa chính bản ghi Review
            DELETE FROM Reviews 
            WHERE review_id = @review_id;

            COMMIT TRANSACTION;
        END TRY
        BEGIN CATCH
            IF @@TRANCOUNT > 0
                ROLLBACK TRANSACTION;
            DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE();
            RAISERROR(@ErrMsg, 16, 1);
        END CATCH;
    END;
END;
GO
PRINT N'-> Đã cập nhật sp_DeleteReview với Transaction thành công.';
GO

-- -----------------------------------------------------------------------------------------
-- 5. sp_DeleteComputerConfig (Xóa dàn máy + Ẩn đề xuất Game_PC_Recommendation trong 1 Transaction)
-- -----------------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_DeleteComputerConfig 
    @pc_id INT,
    @user_id INT
AS
BEGIN 
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NOT EXISTS (
        SELECT 1 
        FROM User_pc 
        WHERE pc_id = @pc_id AND user_id = @user_id
    )
    BEGIN
        RAISERROR(N'Cấu hình máy không tồn tại hoặc bạn không có quyền xóa.', 16, 1);
        RETURN;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- 1. Tự động ẩn tất cả các bài đề xuất cấu hình (Game_PC_Recommendation) sử dụng dàn máy này
        IF EXISTS (SELECT 1 FROM sys.tables WHERE name = 'Game_PC_Recommendation')
        BEGIN
            UPDATE Game_PC_Recommendation
            SET is_hidden = 1
            WHERE pc_id = @pc_id AND user_id = @user_id;
        END;

        -- 2. Xóa cấu hình máy (trigger trg_UserPC_InsteadOfDelete sẽ cập nhật is_deleted = 1)
        DELETE FROM User_pc
        WHERE pc_id = @pc_id AND user_id = @user_id;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@ErrMsg, 16, 1);
    END CATCH;
END;
GO
PRINT N'-> Đã cập nhật sp_DeleteComputerConfig với Transaction thành công.';
GO

PRINT N'=========================================================================================';
PRINT N'HOÀN TẤT MIGRATION: Toàn bộ 5 Stored Procedures đã được bổ sung Transaction an toàn 100%!';
PRINT N'=========================================================================================';
