-- =========================================================================================
-- FILE DEMO: STORED PROCEDURE [dbo].[sp_ReportReview]
-- THƯ MỤC: e:\Antigravity IDE\gamefit\gamefit-db\demo_script\sp\
-- MỤC ĐÍCH: KIỂM THỬ THỦ TỤC BÁO CÁO ĐÁNH GIÁ VI PHẠM (KÈM CÁC RÀNG BUỘC NGHIỆP VỤ BẢO MẬT)
-- PHỤC VỤ: CHẠY TRỰC TIẾP TRÊN SSMS & BÁO CÁO VẤN ĐÁP ĐỒ ÁN GAMEFIT
-- =========================================================================================

USE gamefit_db;
GO

PRINT N'=========================================================================================';
PRINT N'BẮT ĐẦU CHẠY DEMO SP: sp_ReportReview';
PRINT N'=========================================================================================';
GO

-- -----------------------------------------------------------------------------------------
-- BƯỚC 0: CHUẨN BỊ DỮ LIỆU TEST (SETUP)
-- -----------------------------------------------------------------------------------------
PRINT N'-----------------------------------------------------------------------------------------';
PRINT N'BƯỚC 0: CHUẨN BỊ DỮ LIỆU TEST';
PRINT N'-----------------------------------------------------------------------------------------';

-- 1. Lấy 1 Game hợp lệ
DECLARE @GameId INT = (SELECT TOP 1 game_id FROM Games WHERE is_active = 1);

-- 2. Tạo User viết đánh giá vi phạm (Author)
DECLARE @AuthorId INT;
SELECT @AuthorId = user_id FROM Users WHERE email = 'test_author_rep@gamefit.vn';
IF @AuthorId IS NULL
BEGIN
    INSERT INTO Users (user_name, email, password, role, status)
    VALUES ('author_toxic_user', 'test_author_rep@gamefit.vn', 'hash_pass', 'User', 'Active');
    SET @AuthorId = SCOPE_IDENTITY();
END;

-- 3. Tạo User báo cáo (Reporter)
DECLARE @ReporterId INT;
SELECT @ReporterId = user_id FROM Users WHERE email = 'test_reporter_rep@gamefit.vn';
IF @ReporterId IS NULL
BEGIN
    INSERT INTO Users (user_name, email, password, role, status)
    VALUES ('reporter_user', 'test_reporter_rep@gamefit.vn', 'hash_pass', 'User', 'Active');
    SET @ReporterId = SCOPE_IDENTITY();
END;

-- 4. Dọn dẹp dữ liệu cũ nếu có
DELETE FROM Review_Reports WHERE user_id = @ReporterId;
DELETE FROM Reviews WHERE user_id = @AuthorId AND game_id = @GameId;

-- 5. Tạo 1 Review có nội dung vi phạm tiêu chuẩn cộng đồng, trạng thái ban đầu report_status = 'NONE'
INSERT INTO Reviews (user_id, game_id, rating, comment, is_hidden, report_status, created_at)
VALUES (@AuthorId, @GameId, 1, N'Game dở tệ, mời anh em ghé trang web xxx-cacuoc.com để nhận thưởng 500k!', 0, 'NONE', GETDATE());

DECLARE @ReviewId INT = SCOPE_IDENTITY();

PRINT N'-> Đã khởi tạo dữ liệu mẫu:';
PRINT N'   + Game ID     : ' + CAST(@GameId AS VARCHAR(10));
PRINT N'   + Tác giả     : ID = ' + CAST(@AuthorId AS VARCHAR(10)) + N' (author_toxic_user)';
PRINT N'   + Người report: ID = ' + CAST(@ReporterId AS VARCHAR(10)) + N' (reporter_user)';
PRINT N'   + Review ID   : ' + CAST(@ReviewId AS VARCHAR(10));
PRINT N'   + Trạng thái ban đầu: report_status = NONE, is_hidden = 0';
GO


-- =========================================================================================
-- KỊCH BẢN 1: BÁO CÁO ĐÁNH GIÁ THÀNH CÔNG (HAPPY PATH)
-- Ý nghĩa: Người dùng phát hiện bình luận phản cảm/spam và gửi báo cáo cho quản trị viên
-- =========================================================================================
PRINT N'';
PRINT N'=========================================================================================';
PRINT N'KỊCH BẢN 1: GỬI BÁO CÁO THÀNH CÔNG VỚI LÝ DO HỢP LỆ';
PRINT N'=========================================================================================';

DECLARE @AuthorId INT = (SELECT user_id FROM Users WHERE email = 'test_author_rep@gamefit.vn');
DECLARE @ReporterId INT = (SELECT user_id FROM Users WHERE email = 'test_reporter_rep@gamefit.vn');
DECLARE @GameId INT = (SELECT TOP 1 game_id FROM Games WHERE is_active = 1);
DECLARE @ReviewId INT = (SELECT review_id FROM Reviews WHERE user_id = @AuthorId AND game_id = @GameId);

PRINT N'[Trước khi báo cáo]:';
SELECT review_id, user_id, rating, comment, report_status, is_hidden
FROM Reviews
WHERE review_id = @ReviewId;

-- Thực thi thủ tục báo cáo
EXEC sp_ReportReview 
    @review_id = @ReviewId, 
    @user_id = @ReporterId, 
    @report_reason = N'Spam / Quảng cáo trái phép', 
    @report_detail = N'Tài khoản này chèn link cá cược trái phép vào mục bình luận của game.';

PRINT N'[Sau khi báo cáo]:';
-- 1. Xem trạng thái bài review (đã chuyển sang PENDING)
SELECT review_id, user_id, rating, comment, report_status, is_hidden
FROM Reviews
WHERE review_id = @ReviewId;

-- 2. Xem bản ghi được tạo trong bảng Review_Reports
SELECT report_id, review_id, user_id AS reporter_id, report_reason, report_detail, reported_at
FROM Review_Reports
WHERE review_id = @ReviewId;

PRINT N'-> KẾT QUẢ 1: Thành công! report_status đã chuyển thành PENDING và bản ghi báo cáo đã được lưu vào Review_Reports.';
GO


-- =========================================================================================
-- KỊCH BẢN 2: VALIDATION - CHẶN NGƯỜI DÙNG TỰ BÁO CÁO BÌNH LUẬN CỦA CHÍNH MÌNH
-- Ý nghĩa: Ngăn chặn thao tác vô nghĩa hoặc phá hoại quy trình kiểm duyệt
-- =========================================================================================
PRINT N'';
PRINT N'=========================================================================================';
PRINT N'KỊCH BẢN 2: BẮT LỖI TÁC GIẢ TỰ BÁO CÁO BÀI VIẾT CỦA MÌNH';
PRINT N'=========================================================================================';

DECLARE @AuthorId INT = (SELECT user_id FROM Users WHERE email = 'test_author_rep@gamefit.vn');
DECLARE @GameId INT = (SELECT TOP 1 game_id FROM Games WHERE is_active = 1);
DECLARE @ReviewId INT = (SELECT review_id FROM Reviews WHERE user_id = @AuthorId AND game_id = @GameId);

BEGIN TRY
    PRINT N'Tác giả (ID = ' + CAST(@AuthorId AS VARCHAR(10)) + N') cố tình tự báo cáo review của mình...';
    EXEC sp_ReportReview 
        @review_id = @ReviewId, 
        @user_id = @AuthorId, 
        @report_reason = N'Tự tố cáo mình', 
        @report_detail = N'Tôi muốn tự report';

    PRINT N'LỖI TEST: Không được phép báo cáo thành công!';
END TRY
BEGIN CATCH
    PRINT N'-> KẾT QUẢ 2 (Bắt lỗi chuẩn): ' + ERROR_MESSAGE();
END CATCH;
GO


-- =========================================================================================
-- KỊCH BẢN 3: VALIDATION - CHẶN GỬI BÁO CÁO TRÙNG LẶP (DUPLICATE REPORT CHECK)
-- Ý nghĩa: Một người chỉ được báo cáo 1 bài review 1 lần trong khi chờ Admin xử lý, chống spam nút report
-- =========================================================================================
PRINT N'';
PRINT N'=========================================================================================';
PRINT N'KỊCH BẢN 3: BẮT LỖI NGƯỜI BÁO CÁO GỬI LẠI LẦN NỮA (CHỐNG SPAM)';
PRINT N'=========================================================================================';

DECLARE @AuthorId INT = (SELECT user_id FROM Users WHERE email = 'test_author_rep@gamefit.vn');
DECLARE @ReporterId INT = (SELECT user_id FROM Users WHERE email = 'test_reporter_rep@gamefit.vn');
DECLARE @GameId INT = (SELECT TOP 1 game_id FROM Games WHERE is_active = 1);
DECLARE @ReviewId INT = (SELECT review_id FROM Reviews WHERE user_id = @AuthorId AND game_id = @GameId);

BEGIN TRY
    PRINT N'Người báo cáo (ID = ' + CAST(@ReporterId AS VARCHAR(10)) + N') cố tình bấm nút báo cáo lần 2...';
    EXEC sp_ReportReview 
        @review_id = @ReviewId, 
        @user_id = @ReporterId, 
        @report_reason = N'Spam lần 2', 
        @report_detail = N'Gửi thêm lần nữa cho chắc';

    PRINT N'LỖI TEST: Không được phép báo cáo trùng lặp!';
END TRY
BEGIN CATCH
    PRINT N'-> KẾT QUẢ 3 (Bắt lỗi chuẩn): ' + ERROR_MESSAGE();
END CATCH;
GO


-- =========================================================================================
-- KỊCH BẢN 4: VALIDATION - BÁO CÁO REVIEW KHÔNG TỒN TẠI (ID ẢO = 999999)
-- Ý nghĩa: Kiểm tra ràng buộc tồn tại review
-- =========================================================================================
PRINT N'';
PRINT N'=========================================================================================';
PRINT N'KỊCH BẢN 4: BẮT LỖI REVIEW KHÔNG TỒN TẠI';
PRINT N'=========================================================================================';

DECLARE @ReporterId INT = (SELECT user_id FROM Users WHERE email = 'test_reporter_rep@gamefit.vn');

BEGIN TRY
    PRINT N'Gửi báo cáo cho Review ID = 999999...';
    EXEC sp_ReportReview 
        @review_id = 999999, 
        @user_id = @ReporterId, 
        @report_reason = N'Báo cáo ảo';

    PRINT N'LỖI TEST: Không được phép báo cáo thành công!';
END TRY
BEGIN CATCH
    PRINT N'-> KẾT QUẢ 4 (Bắt lỗi chuẩn): ' + ERROR_MESSAGE();
END CATCH;
GO


-- -----------------------------------------------------------------------------------------
-- BƯỚC CLEANUP: DỌN DẸP DỮ LIỆU TEST
-- -----------------------------------------------------------------------------------------
PRINT N'';
PRINT N'-----------------------------------------------------------------------------------------';
PRINT N'DỌN DẸP DỮ LIỆU TEST (CLEANUP)';
PRINT N'-----------------------------------------------------------------------------------------';

DECLARE @AuthorId INT = (SELECT user_id FROM Users WHERE email = 'test_author_rep@gamefit.vn');
DECLARE @GameId INT = (SELECT TOP 1 game_id FROM Games WHERE is_active = 1);

IF @AuthorId IS NOT NULL
BEGIN
    DELETE FROM Reviews WHERE user_id = @AuthorId AND game_id = @GameId;
END;

DELETE FROM Users WHERE email IN ('test_author_rep@gamefit.vn', 'test_reporter_rep@gamefit.vn');
PRINT N'-> Đã dọn dẹp các bản ghi test trong Reviews, Review_Reports và Users.';
GO

PRINT N'=========================================================================================';
PRINT N'HOÀN TẤT DEMO SP: sp_ReportReview';
PRINT N'=========================================================================================';
GO
