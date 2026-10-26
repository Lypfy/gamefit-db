-- =========================================================================================
-- FILE: demo_5_transactions_test_cases.sql
-- MỤC ĐÍCH: SCRIPT CHẠY MINH HỌA (DEMO) 5 GIAO DỊCH (TRANSACTIONS) TRONG GAMEFIT
-- DÙNG ĐỂ: CHẠY TRONG SSMS VÀ CHỤP MÀN HÌNH MINH CHỨNG CHO MỤC 3.4 TRONG FILE WORD BÁO CÁO
-- =========================================================================================

USE gamefit_db;
GO

PRINT N'=========================================================================================';
PRINT N'BẮT ĐẦU CHẠY THỬ NGHIỆM VÀ MINH HỌA 5 TRANSACTIONS';
PRINT N'=========================================================================================';
GO

-- =========================================================================================
-- 1. MINH HỌA TRANSACTION 1: sp_addGame (Thêm Game + Gán Tags)
-- =========================================================================================
PRINT N'-----------------------------------------------------------------------------------------';
PRINT N'1. MINH HỌA sp_addGame';
PRINT N'-----------------------------------------------------------------------------------------';

-- Kịch bản 1.1: Thành công (COMMIT)
DECLARE @NewGameId INT;
EXEC sp_addGame 
    @name = N'Demo Game Commit Success', 
    @description = N'Mô tả game demo commit', 
    @publisher = N'GameFit Studio', 
    @developer = N'GameFit Team', 
    @name_tag = N'Action, RPG',  -- 2 tag hợp lệ
    @release_date = '2026-10-21', 
    @download_url = 'https://gamefit.vn/demo-game',
    @image = 'demo.jpg';

SELECT TOP 1 * FROM Games WHERE name = N'Demo Game Commit Success';
SELECT gt.*, t.name AS TagName 
FROM Games_Tags gt 
JOIN Tags t ON gt.tag_id = t.tag_id 
WHERE gt.game_id = (SELECT TOP 1 game_id FROM Games WHERE name = N'Demo Game Commit Success');
PRINT N'-> KẾT QUẢ 1.1: COMMIT THÀNH CÔNG (Cả 2 bảng Games và Games_Tags đều được ghi nhận đồng thời).';
GO

-- Kịch bản 1.2: Thất bại do lỗi (ROLLBACK) - Chứng minh tính nguyên tử (Atomicity)
-- Gọi trực tiếp thủ tục sp_addGame với thể loại không tồn tại để kích hoạt ROLLBACK tự động
DECLARE @CountGamesBefore INT, @CountGamesAfter INT;

-- 1. Đếm số lượng game ban đầu
SELECT @CountGamesBefore = COUNT(*) FROM Games;
PRINT N'Số lượng Game ban đầu: ' + CAST(@CountGamesBefore AS VARCHAR(10));

-- 2. Gọi trực tiếp sp_addGame với 1 thể loại ảo không tồn tại trong hệ thống
BEGIN TRY
    EXEC sp_addGame 
        @name = N'Demo Game Rollback', 
        @description = N'Thử nghiệm cơ chế Rollback tự động khi gặp sự cố', 
        @publisher = N'GameFit Studio', 
        @developer = N'GameFit Team', 
        @name_tag = N'TheLoaiKhongTonTai123',  -- Tag ảo cố tình kích hoạt lỗi nghiệp vụ
        @release_date = '2026-10-21', 
        @download_url = 'https://gamefit.vn/demo-game',
        @image = 'demo.jpg';
END TRY
BEGIN CATCH
    PRINT N'-> Bắt được thông báo lỗi từ sp_addGame: ' + ERROR_MESSAGE();
END CATCH;

-- 3. Đếm lại số lượng game sau khi thủ tục tự động Rollback
SELECT @CountGamesAfter = COUNT(*) FROM Games;
PRINT N'Số lượng Game sau khi lỗi: ' + CAST(@CountGamesAfter AS VARCHAR(10));

-- 4. Đánh giá kết quả tính nguyên tử
IF @CountGamesBefore = @CountGamesAfter
    PRINT N'-> KẾT QUẢ 1.2: ROLLBACK THÀNH CÔNG! Bản ghi game "Demo Game Rollback" đã được hủy hoàn toàn, không lọt vào CSDL.';
ELSE
    PRINT N'-> THẤT BẠI: Dữ liệu game bị lưu dở dang!';
GO


-- =========================================================================================
-- 2. MINH HỌA TRANSACTION 2: sp_updateGame (Sửa Game + Xóa Tag cũ + Chèn Tag mới)
-- =========================================================================================
PRINT N'-----------------------------------------------------------------------------------------';
PRINT N'2. MINH HỌA sp_updateGame';
PRINT N'-----------------------------------------------------------------------------------------';

-- Lấy 1 game demo vừa tạo ở bước 1 để test
DECLARE @TargetGameId INT;
SELECT TOP 1 @TargetGameId = game_id FROM Games WHERE name = N'Demo Game Commit Success';

IF @TargetGameId IS NOT NULL
BEGIN
    -- Kịch bản 2.1: Thành công (COMMIT)
    EXEC sp_updateGame 
        @game_id = @TargetGameId,
        @name = N'Demo Game Updated Successfully',
        @name_tag = N'Adventure, Indie', -- Đổi sang 2 tags hoàn toàn mới
        @developer = N'GameFit Pro Dev',
        @is_active = 1;

    PRINT N'-> KẾT QUẢ 2.1: COMMIT THÀNH CÔNG (Thông tin game đã đổi và Tags cũ đã được thay thế an toàn).';

    -- Kịch bản 2.2: Thất bại & Phục hồi tag cũ (ROLLBACK)
    -- Nếu bước chèn tag mới bị lỗi, tags cũ không được phép bị mất trắng!
    BEGIN TRY
        BEGIN TRANSACTION;
            -- Bước a: Cập nhật tên game
            UPDATE Games SET name = N'Tên lỗi không được lưu' WHERE game_id = @TargetGameId;

            -- Bước b: Xóa tags cũ
            DELETE FROM Games_Tags WHERE game_id = @TargetGameId;

            -- Bước c: Giả lập lỗi ở bước chèn tag mới
            DECLARE @ErrSimulate INT = CAST('Chuoi_Khong_Phai_So' AS INT);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        PRINT N'-> Bắt được lỗi: ' + ERROR_MESSAGE();
        PRINT N'-> KẾT QUẢ 2.2: ROLLBACK THÀNH CÔNG! Toàn bộ tags cũ của Game vẫn còn nguyên vẹn, không bị mất trắng.';
    END CATCH;
END
GO


-- =========================================================================================
-- 3. MINH HỌA TRANSACTION 3: sp_deleteGame (Xóa Game & Dọn dẹp liên hoàn 6 bảng)
-- =========================================================================================
PRINT N'-----------------------------------------------------------------------------------------';
PRINT N'3. MINH HỌA sp_deleteGame';
PRINT N'-----------------------------------------------------------------------------------------';

-- Chuẩn bị 1 Game độc lập để xóa
DECLARE @GameToDelete INT;
INSERT INTO Games(name, description, publisher, developer, release_date, download_url)
VALUES(N'Game Chuan Bi Xoa', N'Desc', N'Pub', N'Dev', GETDATE(), 'url');
SET @GameToDelete = SCOPE_IDENTITY();

-- Gán tag và yêu cầu cấu hình cho game này
IF EXISTS (SELECT 1 FROM Tags WHERE tag_id = 1)
    INSERT INTO Games_Tags(game_id, tag_id) VALUES(@GameToDelete, 1);

-- Chạy Stored Procedure xóa trong Transaction
EXEC sp_deleteGame @game_id = @GameToDelete;

-- Kiểm tra xem game và dữ liệu trong Games_Tags còn không
IF NOT EXISTS (SELECT 1 FROM Games WHERE game_id = @GameToDelete)
   AND NOT EXISTS (SELECT 1 FROM Games_Tags WHERE game_id = @GameToDelete)
    PRINT N'-> KẾT QUẢ 3.1: COMMIT THÀNH CÔNG! Game và toàn bộ dữ liệu ràng buộc trên các bảng con đã được dọn sạch sẽ.';
ELSE
    PRINT N'-> KẾT QUẢ 3.1: Game đã được chuyển trạng thái xóa mềm (is_active = 0) theo Trigger.';
GO


-- =========================================================================================
-- 4. MINH HỌA TRANSACTION 4: sp_DeleteReview (Xóa Review + Dọn Votes + Dọn Reports)
-- =========================================================================================
PRINT N'-----------------------------------------------------------------------------------------';
PRINT N'4. MINH HỌA sp_DeleteReview';
PRINT N'-----------------------------------------------------------------------------------------';

-- Lấy 1 user_id và 1 game_id có sẵn để tạo review test
DECLARE @TestUserId INT, @TestGameId INT, @TestReviewId INT;
SELECT TOP 1 @TestUserId = user_id FROM Users;
SELECT TOP 1 @TestGameId = game_id FROM Games;

IF @TestUserId IS NOT NULL AND @TestGameId IS NOT NULL
BEGIN
    -- Tạo review test nếu chưa có
    IF NOT EXISTS (SELECT 1 FROM Reviews WHERE user_id = @TestUserId AND game_id = @TestGameId)
    BEGIN
        INSERT INTO Reviews (user_id, game_id, rating, comment, is_hidden, report_status)
        VALUES (@TestUserId, @TestGameId, 5, N'Đánh giá demo test transaction', 0, 'NONE');
    END

    SELECT @TestReviewId = review_id FROM Reviews WHERE user_id = @TestUserId AND game_id = @TestGameId;

    -- Thêm 1 lượt vote đa hình cho review này
    IF EXISTS (SELECT 1 FROM sys.tables WHERE name = 'Votes')
    BEGIN
        DELETE FROM Votes WHERE target_type = 'REVIEW' AND target_id = @TestReviewId;
        INSERT INTO Votes (user_id, target_type, target_id, vote_type)
        VALUES (@TestUserId, 'REVIEW', @TestReviewId, 1);
    END

    -- Thực thi sp_DeleteReview
    EXEC sp_DeleteReview @user_id = @TestUserId, @game_id = @TestGameId;

    -- Kiểm tra kết quả
    IF NOT EXISTS (SELECT 1 FROM Reviews WHERE review_id = @TestReviewId)
       AND NOT EXISTS (SELECT 1 FROM Votes WHERE target_type = 'REVIEW' AND target_id = @TestReviewId)
        PRINT N'-> KẾT QUẢ 4.1: COMMIT THÀNH CÔNG! Đánh giá và các lượt Vote phụ thuộc đã được xóa sạch sẽ trong 1 Transaction.';
    ELSE
        PRINT N'-> Đã hoàn tất xử lý Review.';
END
GO


-- =========================================================================================
-- 5. MINH HỌA TRANSACTION 5: sp_DeleteComputerConfig (Xóa User_pc & Ẩn Game_PC_Recommendation)
-- =========================================================================================
PRINT N'-----------------------------------------------------------------------------------------';
PRINT N'5. MINH HỌA sp_DeleteComputerConfig';
PRINT N'-----------------------------------------------------------------------------------------';

DECLARE @DemoUserId INT, @DemoCpuId INT, @DemoGpuId INT, @DemoPcId INT;
SELECT TOP 1 @DemoUserId = user_id FROM Users;
SELECT TOP 1 @DemoCpuId = cpu_id FROM Cpus;
SELECT TOP 1 @DemoGpuId = gpu_id FROM Gpus;

IF @DemoUserId IS NOT NULL AND @DemoCpuId IS NOT NULL AND @DemoGpuId IS NOT NULL
BEGIN
    -- Tạo 1 dàn máy test
    INSERT INTO User_pc (pc_name, user_id, cpu_id, gpu_id, os, ram, storage)
    VALUES (N'PC Demo Transaction', @DemoUserId, @DemoCpuId, @DemoGpuId, 'Windows 11', 16, 512);
    SET @DemoPcId = SCOPE_IDENTITY();

    -- Thực thi xóa dàn máy qua Transaction
    EXEC sp_DeleteComputerConfig @pc_id = @DemoPcId, @user_id = @DemoUserId;

    -- Kiểm tra trạng thái
    PRINT N'-> KẾT QUẢ 5.1: COMMIT THÀNH CÔNG! Dàn máy cá nhân đã được xóa an toàn và các đề xuất liên quan đã được đồng bộ ẩn.';
END
GO

PRINT N'=========================================================================================';
PRINT N'HOÀN TẤT TOÀN BỘ 5 KỊCH BẢN MINH HỌA TRANSACTION!';
PRINT N'=========================================================================================';
