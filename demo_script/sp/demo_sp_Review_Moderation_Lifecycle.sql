-- =========================================================================================
-- FILE DEMO VẤN ĐÁP TỔNG HỢP: QUY TRÌNH TOÀN DIỆN VÒNG ĐỜI ĐÁNH GIÁ & KIỂM DUYỆT (REVIEW LIFECYCLE)
-- THƯ MỤC: e:\Antigravity IDE\gamefit\gamefit-db\demo_script\sp\
-- BỘ 6 STORED PROCEDURES ĐƯỢC DEMO TRONG LUỒNG NGHIỆP VỤ LIÊN TỤC:
--   1. sp_UpdateReview           : Cập nhật điểm rating và bình luận
--   2. sp_ReportReview           : Báo cáo đánh giá vi phạm (kèm chặn tự report & chống duplicate)
--   3. sp_GetReportedReviews     : Admin truy vấn danh sách đánh giá bị tố cáo (lọc status, time, search)
--   4. sp_GetReviewReportDetails : Admin xem chi tiết danh sách người đã tố cáo và nội dung phản ánh
--   5. sp_ModerateReview         : Admin xử lý (HIDE ẩn bài / DISMISS bỏ qua & tự động gửi Notification)
--   6. sp_DeleteReview           : Xóa đánh giá (tự động xóa sạch báo cáo liên quan nhờ ON DELETE CASCADE)
-- =========================================================================================

USE gamefit_db;
GO

PRINT N'=========================================================================================';
PRINT N'BẮT ĐẦU CHẠY DEMO QUY TRÌNH VÒNG ĐỜI ĐÁNH GIÁ & KIỂM DUYỆT (REVIEW LIFECYCLE FLOW)';
PRINT N'=========================================================================================';
GO

-- -----------------------------------------------------------------------------------------
-- BƯỚC 0: CHUẨN BỊ MÔI TRƯỜNG & DỮ LIỆU TEST (SETUP)
-- -----------------------------------------------------------------------------------------
PRINT N'-----------------------------------------------------------------------------------------';
PRINT N'BƯỚC 0: KHỞI TẠO TÀI KHOẢN VÀ BÀI ĐÁNH GIÁ BAN ĐẦU';
PRINT N'-----------------------------------------------------------------------------------------';

-- 1. Lấy 1 Game hợp lệ từ vw_Game_Detail
DECLARE @GameId INT = (SELECT TOP 1 game_id FROM vw_Game_Detail);

-- 2. Tạo User viết đánh giá (Author)
DECLARE @AuthorId INT;
SELECT @AuthorId = user_id FROM Users WHERE email = 'lifecycle_author@gamefit.vn';
IF @AuthorId IS NULL
BEGIN
    INSERT INTO Users (user_name, email, password, role, status)
    VALUES ('gamer_author', 'lifecycle_author@gamefit.vn', 'pass123', 'User', 'Active');
    SET @AuthorId = SCOPE_IDENTITY();
END;

-- 3. Tạo User báo cáo vi phạm (Reporter)
DECLARE @ReporterId INT;
SELECT @ReporterId = user_id FROM Users WHERE email = 'lifecycle_reporter@gamefit.vn';
IF @ReporterId IS NULL
BEGIN
    INSERT INTO Users (user_name, email, password, role, status)
    VALUES ('gamer_reporter', 'lifecycle_reporter@gamefit.vn', 'pass123', 'User', 'Active');
    SET @ReporterId = SCOPE_IDENTITY();
END;

-- 4. Dọn dẹp dữ liệu cũ nếu có
DELETE FROM Notifications WHERE user_id IN (@AuthorId, @ReporterId);
DELETE FROM Review_Reports WHERE user_id IN (@AuthorId, @ReporterId);
DELETE FROM Reviews WHERE user_id = @AuthorId;

-- 5. Tạo 1 Review ban đầu: 3 sao, bình luận bình thường
INSERT INTO Reviews (user_id, game_id, rating, comment, is_hidden, report_status, created_at)
VALUES (@AuthorId, @GameId, 3, N'Bình luận gốc: Game chơi ở mức trung bình, chưa có gì nổi bật.', 0, 'NONE', GETDATE());
DECLARE @ReviewId INT = SCOPE_IDENTITY();

PRINT N'-> Đã khởi tạo:';
PRINT N'   + Game ID    : ' + CAST(@GameId AS VARCHAR(10));
PRINT N'   + Author ID  : ' + CAST(@AuthorId AS VARCHAR(10)) + N' (gamer_author)';
PRINT N'   + Reporter ID: ' + CAST(@ReporterId AS VARCHAR(10)) + N' (gamer_reporter)';
PRINT N'   + Review ID  : ' + CAST(@ReviewId AS VARCHAR(10)) + N' (Rating: 3 sao, report_status: NONE)';
GO


-- =========================================================================================
-- GIAI ĐOẠN 1: NGƯỜI DÙNG SỬA ĐÁNH GIÁ (sp_UpdateReview)
-- Mục đích: Đổi rating lên 1 sao và chèn link spam vi phạm tiêu chuẩn cộng đồng
-- =========================================================================================
PRINT N'';
PRINT N'=========================================================================================';
PRINT N'GIAI ĐOẠN 1: GỌI sp_UpdateReview ĐỂ CẬP NHẬT RATING VÀ NỘI DUNG BÌNH LUẬN';
PRINT N'=========================================================================================';

DECLARE @AuthorId INT = (SELECT user_id FROM Users WHERE email = 'lifecycle_author@gamefit.vn');
DECLARE @GameId INT = (SELECT TOP 1 game_id FROM vw_Game_Detail);

PRINT N'[Trước khi cập nhật]:';
SELECT review_id, user_id, rating, comment, report_status 
FROM Reviews WHERE user_id = @AuthorId AND game_id = @GameId;

-- Thực hiện cập nhật
EXEC sp_UpdateReview 
    @user_id = @AuthorId, 
    @game_id = @GameId, 
    @rating = 1, 
    @comment = N'Cập nhật: Game quá tệ! Ghé ngay lừa-đảo-game.net để nạp giftcode hoàn tiền 200%!';

PRINT N'[Sau khi cập nhật]:';
SELECT review_id, user_id, rating, comment, report_status 
FROM Reviews WHERE user_id = @AuthorId AND game_id = @GameId;

PRINT N'-> KẾT QUẢ 1: sp_UpdateReview cập nhật thành công (rating thành 1 sao và nội dung đã đổi).';
GO


-- =========================================================================================
-- GIAI ĐOẠN 2: CỘNG ĐỒNG PHÁT HIỆN VÀ GỬI BÁO CÁO (sp_ReportReview)
-- Mục đích: Người dùng khác thấy link lừa đảo/spam nên bấm nút Báo cáo
-- =========================================================================================
PRINT N'';
PRINT N'=========================================================================================';
PRINT N'GIAI ĐOẠN 2: GỌI sp_ReportReview ĐỂ BÁO CÁO VI PHẠM';
PRINT N'=========================================================================================';

DECLARE @AuthorId INT = (SELECT user_id FROM Users WHERE email = 'lifecycle_author@gamefit.vn');
DECLARE @ReporterId INT = (SELECT user_id FROM Users WHERE email = 'lifecycle_reporter@gamefit.vn');
DECLARE @ReviewId INT = (SELECT TOP 1 review_id FROM Reviews WHERE user_id = @AuthorId);

-- Thực hiện báo cáo
EXEC sp_ReportReview 
    @review_id = @ReviewId, 
    @user_id = @ReporterId, 
    @report_reason = N'Lừa đảo / Phishing', 
    @report_detail = N'Người này cố tình chia sẻ link độc hại lừa đảo người dùng khác.';

PRINT N'[Kiểm tra bảng Reviews]: report_status đã chuyển thành PENDING:';
SELECT review_id, user_id, rating, comment, report_status, is_hidden 
FROM Reviews WHERE review_id = @ReviewId;

PRINT N'[Kiểm tra bảng Review_Reports]: Bản ghi báo cáo đã được lưu:';
SELECT report_id, review_id, user_id AS reporter_id, report_reason, report_detail, reported_at 
FROM Review_Reports WHERE review_id = @ReviewId;

PRINT N'-> KẾT QUẢ 2: sp_ReportReview đã ghi nhận báo cáo và chuyển trạng thái review sang PENDING.';
GO


-- =========================================================================================
-- GIAI ĐOẠN 3: ADMIN TRUY VẤN DANH SÁCH BÁO CÁO CẦN DUYỆT (sp_GetReportedReviews)
-- Mục đích: Admin mở trang Quản trị để theo dõi các bài viết đang bị cộng đồng phản ánh
-- =========================================================================================
PRINT N'';
PRINT N'=========================================================================================';
PRINT N'GIAI ĐOẠN 3: ADMIN GỌI sp_GetReportedReviews XEM CÁC BÀI VIẾT CHỜ DUYỆT';
PRINT N'=========================================================================================';

EXEC sp_GetReportedReviews 
    @status = 'PENDING', 
    @time_range = 'all', 
    @search = NULL;

PRINT N'-> KẾT QUẢ 3: sp_GetReportedReviews trả về danh sách đầy đủ: Tên người vi phạm, tên game, số lượt báo cáo, lý do và thời gian báo cáo.';
GO


-- =========================================================================================
-- GIAI ĐOẠN 4: ADMIN XEM CHI TIẾT CÁC LƯỢT BÁO CÁO (sp_GetReviewReportDetails)
-- Mục đích: Admin nhấp vào bài viết để mở popup chi tiết xem bằng chứng và danh sách người tố cáo
-- =========================================================================================
PRINT N'';
PRINT N'=========================================================================================';
PRINT N'GIAI ĐOẠN 4: ADMIN GỌI sp_GetReviewReportDetails ĐỂ XEM CHI TIẾT PHẢN ÁNH';
PRINT N'=========================================================================================';

DECLARE @AuthorId INT = (SELECT user_id FROM Users WHERE email = 'lifecycle_author@gamefit.vn');
DECLARE @ReviewId INT = (SELECT TOP 1 review_id FROM Reviews WHERE user_id = @AuthorId);

EXEC sp_GetReviewReportDetails @review_id = @ReviewId;

PRINT N'-> KẾT QUẢ 4: sp_GetReviewReportDetails cung cấp đầy đủ thông tin bằng chứng, lý do cụ thể và tên người gửi báo cáo.';
GO


-- =========================================================================================
-- GIAI ĐOẠN 5: ADMIN THỰC HIỆN KIỂM DUYỆT ẨN BÀI VIẾT (sp_ModerateReview)
-- Mục đích: Admin ẩn bình luận vi phạm và hệ thống tự động bắn thông báo cho các bên liên quan
-- =========================================================================================
PRINT N'';
PRINT N'=========================================================================================';
PRINT N'GIAI ĐOẠN 5: ADMIN GỌI sp_ModerateReview VỚI ACTION = ''HIDE''';
PRINT N'=========================================================================================';

DECLARE @AuthorId INT = (SELECT user_id FROM Users WHERE email = 'lifecycle_author@gamefit.vn');
DECLARE @ReporterId INT = (SELECT user_id FROM Users WHERE email = 'lifecycle_reporter@gamefit.vn');
DECLARE @ReviewId INT = (SELECT TOP 1 review_id FROM Reviews WHERE user_id = @AuthorId);

-- Admin duyệt ẩn
EXEC sp_ModerateReview @review_id = @ReviewId, @action = 'HIDE';

PRINT N'[5.1] Trạng thái Review sau khi Admin ẩn:';
SELECT review_id, user_id, comment, is_hidden, report_status 
FROM Reviews WHERE review_id = @ReviewId;

PRINT N'[5.2] Kiểm tra thông báo tự động phát sinh trong Notifications:';
SELECT notification_id, user_id, title, message, type, target_url, created_at 
FROM Notifications 
WHERE user_id IN (@AuthorId, @ReporterId)
ORDER BY created_at DESC;

PRINT N'-> KẾT QUẢ 5:';
PRINT N'   + is_hidden = 1, report_status = HIDDEN.';
PRINT N'   + Tác giả nhận được thông báo REVIEW_HIDDEN giải thích lý do bài bị ẩn.';
PRINT N'   + Người gửi báo cáo nhận được thông báo REPORT_RESULT cảm ơn đã đóng góp làm trong sạch cộng đồng.';
GO


-- =========================================================================================
-- GIAI ĐOẠN 6: XÓA ĐÁNH GIÁ VÀ KIỂM CHỨNG CASCADE DELETE (sp_DeleteReview)
-- Mục đích: Đánh giá bị xóa hoàn toàn khỏi hệ thống, các báo cáo liên quan tự động xóa theo
-- =========================================================================================
PRINT N'';
PRINT N'=========================================================================================';
PRINT N'GIAI ĐOẠN 6: GỌI sp_DeleteReview VÀ KIỂM CHỨNG TỰ ĐỘNG XÓA BÁO CÁO (ON DELETE CASCADE)';
PRINT N'=========================================================================================';

DECLARE @AuthorId INT = (SELECT user_id FROM Users WHERE email = 'lifecycle_author@gamefit.vn');
DECLARE @GameId INT = (SELECT TOP 1 game_id FROM vw_Game_Detail);
DECLARE @TargetReviewId INT = (SELECT TOP 1 review_id FROM Reviews WHERE user_id = @AuthorId);

-- Thực hiện xóa
EXEC sp_DeleteReview @user_id = @AuthorId, @game_id = @GameId;

PRINT N'[6.1] Bảng Reviews sau khi xóa (Kỳ vọng: 0 dòng):';
SELECT review_id, user_id, game_id, comment 
FROM Reviews WHERE user_id = @AuthorId AND game_id = @GameId;

PRINT N'[6.2] Bảng Review_Reports sau khi xóa (Kỳ vọng: 0 dòng nhờ ON DELETE CASCADE):';
SELECT report_id, review_id, user_id, report_reason 
FROM Review_Reports WHERE review_id = @TargetReviewId;

PRINT N'-> KẾT QUẢ 6: sp_DeleteReview đã xóa hoàn toàn đánh giá. Khóa ngoại CASCADE tự động dọn sạch bảng Review_Reports!';
GO


-- -----------------------------------------------------------------------------------------
-- BƯỚC CLEANUP: DỌN DẸP SẠCH CÁC TÀI KHOẢN VÀ THÔNG BÁO TEST
-- -----------------------------------------------------------------------------------------
PRINT N'';
PRINT N'-----------------------------------------------------------------------------------------';
PRINT N'DỌN DẸP DỮ LIỆU TEST (CLEANUP)';
PRINT N'-----------------------------------------------------------------------------------------';

DECLARE @AuthorId INT = (SELECT user_id FROM Users WHERE email = 'lifecycle_author@gamefit.vn');
DECLARE @ReporterId INT = (SELECT user_id FROM Users WHERE email = 'lifecycle_reporter@gamefit.vn');

IF @AuthorId IS NOT NULL OR @ReporterId IS NOT NULL
BEGIN
    DELETE FROM Notifications WHERE user_id IN (@AuthorId, @ReporterId);
    DELETE FROM Review_Reports WHERE user_id IN (@AuthorId, @ReporterId);
    DELETE FROM Reviews WHERE user_id IN (@AuthorId, @ReporterId);
    DELETE FROM Users WHERE email IN ('lifecycle_author@gamefit.vn', 'lifecycle_reporter@gamefit.vn');
END;

PRINT N'-> Đã dọn dẹp sạch sẽ tài khoản và thông báo demo.';
GO

PRINT N'=========================================================================================';
PRINT N'HOÀN TẤT DEMO TOÀN DIỆN VÒNG ĐỜI ĐÁNH GIÁ & KIỂM DUYỆT (REVIEW LIFECYCLE)';
PRINT N'=========================================================================================';
GO
