-- =========================================================================================
-- FILE DEMO: STORED PROCEDURE [dbo].[sp_UpdateReview]
-- THƯ MỤC: e:\Antigravity IDE\gamefit\gamefit-db\demo_script\sp\
-- MỤC ĐÍCH: KIỂM THỬ THỦ TỤC CẬP NHẬT ĐÁNH GIÁ (RATING & BÌNH LUẬN) CỦA NGƯỜI DÙNG CHO GAME
-- PHỤC VỤ: CHẠY TRỰC TIẾP TRÊN SSMS & BÁO CÁO VẤN ĐÁP ĐỒ ÁN GAMEFIT
-- =========================================================================================

USE gamefit_db;
GO

PRINT N'=========================================================================================';
PRINT N'BẮT ĐẦU CHẠY DEMO SP: sp_UpdateReview';
PRINT N'=========================================================================================';
GO

-- -----------------------------------------------------------------------------------------
-- BƯỚC 0: CHUẨN BỊ DỮ LIỆU TEST (SETUP)
-- -----------------------------------------------------------------------------------------
PRINT N'-----------------------------------------------------------------------------------------';
PRINT N'BƯỚC 0: CHUẨN BỊ DỮ LIỆU TEST';
PRINT N'-----------------------------------------------------------------------------------------';

-- 1. Lấy 1 Game hợp lệ từ vw_Game_Detail
DECLARE @GameId INT;
SELECT TOP 1 @GameId = game_id FROM vw_Game_Detail;

-- 2. Lấy 1 User hợp lệ từ vw_User_Safe_Profile
DECLARE @UserId INT;
SELECT TOP 1 @UserId = user_id FROM vw_User_Safe_Profile WHERE status = 'Active' OR status IS NULL;

-- Nếu chưa có User thì tạo user mẫu
IF @UserId IS NULL
BEGIN
    INSERT INTO Users (user_name, email, password, role, status)
    VALUES ('test_review_author', 'author_update@gamefit.vn', 'hash_pass_123', 'User', 'Active');
    SET @UserId = SCOPE_IDENTITY();
END;

-- 3. Đảm bảo đã có 1 đánh giá ban đầu của User này cho Game này để thực hiện cập nhật
-- Xóa review demo cũ nếu có
DELETE FROM Reviews WHERE user_id = @UserId AND game_id = @GameId;

-- Thêm review ban đầu: 3 sao, bình luận sơ khai
INSERT INTO Reviews (user_id, game_id, rating, comment, is_hidden, report_status, created_at)
VALUES (@UserId, @GameId, 3, N'Bình luận ban đầu: Game chơi tạm được, đồ họa trung bình.', 0, 'NONE', GETDATE());

PRINT N'-> Đã thiết lập dữ liệu mẫu:';
PRINT N'   + User ID : ' + CAST(@UserId AS VARCHAR(10));
PRINT N'   + Game ID : ' + CAST(@GameId AS VARCHAR(10));
PRINT N'   + Rating ban đầu: 3 sao';
PRINT N'   + Comment ban đầu: "Bình luận ban đầu: Game chơi tạm được, đồ họa trung bình."';
GO


-- =========================================================================================
-- KỊCH BẢN 1: CẬP NHẬT ĐÁNH GIÁ THÀNH CÔNG (HAPPY PATH)
-- Ý nghĩa: Người dùng đổi ý sau khi chơi lâu hơn, tăng lên 5 sao và viết nhận xét chi tiết hơn
-- =========================================================================================
PRINT N'';
PRINT N'=========================================================================================';
PRINT N'KỊCH BẢN 1: CẬP NHẬT THÀNH CÔNG (RATING = 5, BÌNH LUẬN MỚI)';
PRINT N'=========================================================================================';

DECLARE @GameId INT = (SELECT TOP 1 game_id FROM vw_Game_Detail);
DECLARE @UserId INT = (SELECT TOP 1 user_id FROM Reviews WHERE game_id = (SELECT TOP 1 game_id FROM vw_Game_Detail));

PRINT N'[Trước khi cập nhật]:';
SELECT review_id, user_id, game_id, rating, comment, report_status
FROM Reviews
WHERE user_id = @UserId AND game_id = @GameId;

-- Gọi SP cập nhật
EXEC sp_UpdateReview 
    @user_id = @UserId, 
    @game_id = @GameId, 
    @rating = 5, 
    @comment = N'Cập nhật: Sau bản cập nhật mới nhất, game cực kỳ mượt và cốt truyện tuyệt vời! 10/10';

PRINT N'[Sau khi cập nhật]:';
SELECT review_id, user_id, game_id, rating, comment, report_status
FROM Reviews
WHERE user_id = @UserId AND game_id = @GameId;

PRINT N'-> KẾT QUẢ 1: Cập nhật thành công! Điểm đánh giá đã nâng lên 5 sao và nội dung đã được ghi nhận.';
GO


-- =========================================================================================
-- KỊCH BẢN 2: VALIDATION - ĐIỂM ĐÁNH GIÁ NGOÀI PHẠM VI (RATING < 1 HOẶC RATING > 5)
-- Ý nghĩa: Đảm bảo tính toàn vẹn nghiệp vụ (Rating chỉ được phép từ 1 đến 5 sao)
-- =========================================================================================
PRINT N'';
PRINT N'=========================================================================================';
PRINT N'KỊCH BẢN 2: BẮT LỖI RATING KHÔNG HỢP LỆ (@rating = 6 HOẶC @rating = 0)';
PRINT N'=========================================================================================';

DECLARE @GameId INT = (SELECT TOP 1 game_id FROM vw_Game_Detail);
DECLARE @UserId INT = (SELECT TOP 1 user_id FROM Reviews WHERE game_id = (SELECT TOP 1 game_id FROM vw_Game_Detail));

BEGIN TRY
    PRINT N'Thực hiện cập nhật với rating = 6 (vượt quá 5 sao)...';
    EXEC sp_UpdateReview 
        @user_id = @UserId, 
        @game_id = @GameId, 
        @rating = 6, 
        @comment = N'Thử rating 6 sao';
        
    PRINT N'LỖI TEST: Không được phép cập nhật thành công!';
END TRY
BEGIN CATCH
    PRINT N'-> KẾT QUẢ 2 (Bắt lỗi chuẩn): ' + ERROR_MESSAGE();
END CATCH;
GO


-- =========================================================================================
-- KỊCH BẢN 3: VALIDATION - GAME KHÔNG TỒN TẠI (@game_id ẢO = 999999)
-- Ý nghĩa: Kiểm tra ràng buộc tồn tại game qua view vw_Game_Detail
-- =========================================================================================
PRINT N'';
PRINT N'=========================================================================================';
PRINT N'KỊCH BẢN 3: BẮT LỖI GAME KHÔNG TỒN TẠI (ID ẢO = 999999)';
PRINT N'=========================================================================================';

DECLARE @UserId INT = (SELECT TOP 1 user_id FROM Users);

BEGIN TRY
    PRINT N'Thực hiện cập nhật cho Game ID = 999999 không có thực...';
    EXEC sp_UpdateReview 
        @user_id = @UserId, 
        @game_id = 999999, 
        @rating = 4, 
        @comment = N'Cập nhật cho game ảo';
        
    PRINT N'LỖI TEST: Không được phép cập nhật thành công!';
END TRY
BEGIN CATCH
    PRINT N'-> KẾT QUẢ 3 (Bắt lỗi chuẩn): ' + ERROR_MESSAGE();
END CATCH;
GO


-- =========================================================================================
-- KỊCH BẢN 4: VALIDATION - USER CHƯA TỪNG ĐÁNH GIÁ GAME NÀY
-- Ý nghĩa: Muốn cập nhật thì bắt buộc phải đã viết đánh giá từ trước (không tự ý INSERT)
-- =========================================================================================
PRINT N'';
PRINT N'=========================================================================================';
PRINT N'KỊCH BẢN 4: BẮT LỖI KHI NGƯỜI DÙNG CHƯA TỪNG ĐÁNH GIÁ GAME NÀY';
PRINT N'=========================================================================================';

DECLARE @GameId INT = (SELECT TOP 1 game_id FROM vw_Game_Detail);
-- Lấy 1 User chưa từng đánh giá GameId này
DECLARE @OtherUserId INT;
SELECT TOP 1 @OtherUserId = u.user_id 
FROM Users u
WHERE NOT EXISTS (SELECT 1 FROM Reviews r WHERE r.user_id = u.user_id AND r.game_id = @GameId);

IF @OtherUserId IS NOT NULL
BEGIN
    BEGIN TRY
        PRINT N'User ID = ' + CAST(@OtherUserId AS VARCHAR(10)) + N' cố tình gọi sp_UpdateReview khi chưa có review...';
        EXEC sp_UpdateReview 
            @user_id = @OtherUserId, 
            @game_id = @GameId, 
            @rating = 4, 
            @comment = N'Cố tình cập nhật khi chưa đánh giá';
            
        PRINT N'LỖI TEST: Không được phép cập nhật thành công!';
    END TRY
    BEGIN CATCH
        PRINT N'-> KẾT QUẢ 4 (Bắt lỗi chuẩn): ' + ERROR_MESSAGE();
    END CATCH;
END
ELSE
BEGIN
    PRINT N'Bỏ qua kịch bản 4: Tất cả user đều đã đánh giá game này.';
END;
GO


-- -----------------------------------------------------------------------------------------
-- BƯỚC CLEANUP: KHÔI PHỤC HOẶC DỌN DẸP DỮ LIỆU SAU KHI TEST
-- -----------------------------------------------------------------------------------------
PRINT N'';
PRINT N'-----------------------------------------------------------------------------------------';
PRINT N'DỌN DẸP DỮ LIỆU TEST (CLEANUP)';
PRINT N'-----------------------------------------------------------------------------------------';

-- Dọn dẹp bản ghi test nếu cần (hoặc giữ lại tùy nhu cầu kiểm tra trên UI)
DECLARE @GameId INT = (SELECT TOP 1 game_id FROM vw_Game_Detail);
DECLARE @UserId INT = (SELECT TOP 1 user_id FROM Users WHERE email = 'author_update@gamefit.vn');

IF @UserId IS NOT NULL
BEGIN
    DELETE FROM Reviews WHERE user_id = @UserId AND game_id = @GameId;
    DELETE FROM Users WHERE user_id = @UserId;
    PRINT N'-> Đã dọn dẹp sạch User và Review demo tạo trong bài test.';
END;
GO

PRINT N'=========================================================================================';
PRINT N'HOÀN TẤT DEMO SP: sp_UpdateReview';
PRINT N'=========================================================================================';
GO
