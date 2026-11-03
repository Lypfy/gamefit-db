-- =========================================================================================
-- FILE DEMO: STORED PROCEDURE [dbo].[sp_GetReportedReviews]
-- THƯ MỤC: e:\Antigravity IDE\gamefit\gamefit-db\demo_script\sp\
-- MỤC ĐÍCH: KIỂM THỬ THỦ TỤC LẤY DANH SÁCH ĐÁNH GIÁ BỊ BÁO CÁO DÀNH CHO ADMIN (LỌC & TÌM KIẾM)
-- PHỤC VỤ: CHẠY TRỰC TIẾP TRÊN SSMS & BÁO CÁO VẤN ĐÁP ĐỒ ÁN GAMEFIT
-- =========================================================================================

USE gamefit_db;
GO

PRINT N'=========================================================================================';
PRINT N'BẮT ĐẦU CHẠY DEMO SP: sp_GetReportedReviews';
PRINT N'=========================================================================================';
GO

-- -----------------------------------------------------------------------------------------
-- BƯỚC 0: CHUẨN BỊ DỮ LIỆU TEST (SETUP ĐA DẠNG TRẠNG THÁI BÁO CÁO)
-- -----------------------------------------------------------------------------------------
PRINT N'-----------------------------------------------------------------------------------------';
PRINT N'BƯỚC 0: CHUẨN BỊ DỮ LIỆU TEST VỚI CÁC TRẠNG THÁI PENDING, HIDDEN, DISMISSED';
PRINT N'-----------------------------------------------------------------------------------------';

-- 1. Lấy 1 Game mẫu
DECLARE @GameId INT = (SELECT TOP 1 game_id FROM Games WHERE is_active = 1);

-- 2. Tạo 2 User: 1 Người viết review (Violator) và 1 Người báo cáo (Reporter)
DECLARE @ViolatorId INT;
SELECT @ViolatorId = user_id FROM Users WHERE email = 'violator_list@gamefit.vn';
IF @ViolatorId IS NULL
BEGIN
    INSERT INTO Users (user_name, email, password, role, status)
    VALUES ('violator_player', 'violator_list@gamefit.vn', 'hash_pass', 'User', 'Active');
    SET @ViolatorId = SCOPE_IDENTITY();
END;

DECLARE @ReporterId INT;
SELECT @ReporterId = user_id FROM Users WHERE email = 'reporter_list@gamefit.vn';
IF @ReporterId IS NULL
BEGIN
    INSERT INTO Users (user_name, email, password, role, status)
    VALUES ('reporter_hero', 'reporter_list@gamefit.vn', 'hash_pass', 'User', 'Active');
    SET @ReporterId = SCOPE_IDENTITY();
END;

-- 3. Dọn dẹp dữ liệu cũ của user này
DELETE FROM Review_Reports WHERE user_id = @ReporterId;
DELETE FROM Reviews WHERE user_id = @ViolatorId;

-- 4. Tạo bài đánh giá Demo A: Trạng thái PENDING, có 1 báo cáo
INSERT INTO Reviews (user_id, game_id, rating, comment, is_hidden, report_status, created_at)
VALUES (@ViolatorId, @GameId, 1, N'Bình luận mẫu A: Bài viết vi phạm cần xử lý ngay!', 0, 'PENDING', DATEADD(MINUTE, -30, GETDATE()));
DECLARE @RevA_Id INT = SCOPE_IDENTITY();

INSERT INTO Review_Reports (review_id, user_id, report_reason, report_detail, reported_at)
VALUES (@RevA_Id, @ReporterId, N'Ngôn từ thô tục / Toxic', N'Sử dụng từ ngữ xúc phạm người chơi khác', DATEADD(HOUR, 7, GETUTCDATE()));

PRINT N'-> Đã khởi tạo bài đánh giá mẫu bị báo cáo:';
PRINT N'   + Review ID    : ' + CAST(@RevA_Id AS VARCHAR(10));
PRINT N'   + Trạng thái   : PENDING';
PRINT N'   + Lý do báo cáo: Ngôn từ thô tục / Toxic';
PRINT N'   + Người report : reporter_hero';
GO


-- =========================================================================================
-- KỊCH BẢN 1: ADMIN XEM DANH SÁCH BÁO CÁO ĐANG CHỜ DUYỆT (@status = 'PENDING')
-- Ý nghĩa: Đây là màn hình mặc định khi Admin vào trang Quản lý kiểm duyệt báo cáo
-- =========================================================================================
PRINT N'';
PRINT N'=========================================================================================';
PRINT N'KỊCH BẢN 1: LẤY DANH SÁCH ĐÁNH GIÁ CHỜ DUYỆT (@status = ''PENDING'')';
PRINT N'=========================================================================================';

EXEC sp_GetReportedReviews 
    @status = 'PENDING', 
    @time_range = 'all', 
    @search = NULL;

PRINT N'-> KẾT QUẢ 1: Trả về các đánh giá đang chờ duyệt với đầy đủ thông tin: tên người vi phạm, tên game, số lượt report, lý do và thời gian báo cáo.';
GO


-- =========================================================================================
-- KỊCH BẢN 2: ADMIN XEM TẤT CẢ TRẠNG THÁI (@status = 'ALL' HOẶC NULL)
-- Ý nghĩa: Xem lại toàn bộ lịch sử các bài đã duyệt (HIDDEN / DISMISSED) lẫn đang chờ (PENDING)
-- Ghi chú thuật toán: Thứ tự sắp xếp sẽ ưu tiên PENDING lên trước, rồi đến bài bị report nhiều nhất
-- =========================================================================================
PRINT N'';
PRINT N'=========================================================================================';
PRINT N'KỊCH BẢN 2: LẤY TẤT CẢ BÁO CÁO (@status = ''ALL'')';
PRINT N'=========================================================================================';

EXEC sp_GetReportedReviews 
    @status = 'ALL', 
    @time_range = 'all', 
    @search = NULL;

PRINT N'-> KẾT QUẢ 2: Trả về đầy đủ tất cả đánh giá bị báo cáo trong hệ thống.';
GO


-- =========================================================================================
-- KỊCH BẢN 3: LỌC THEO KHOẢNG THỜI GIAN (@time_range = 'today', 'week', 'month')
-- Ý nghĩa: Giúp Admin xem báo cáo mới phát sinh trong ngày hôm nay
-- =========================================================================================
PRINT N'';
PRINT N'=========================================================================================';
PRINT N'KỊCH BẢN 3: LỌC THEO THỜI GIAN TRONG NGÀY HÔM NAY (@time_range = ''today'')';
PRINT N'=========================================================================================';

EXEC sp_GetReportedReviews 
    @status = 'ALL', 
    @time_range = 'today', 
    @search = NULL;

PRINT N'-> KẾT QUẢ 3: Trả về các báo cáo phát sinh trong ngày hiện tại theo giờ chuẩn Việt Nam (UTC+7).';
GO


-- =========================================================================================
-- KỊCH BẢN 4: TÌM KIẾM THEO TỪ KHÓA (@search = N'từ khóa')
-- Ý nghĩa: Tìm kiếm nhanh theo tên người dùng vi phạm, nội dung bình luận, hoặc lý do tố cáo
-- =========================================================================================
PRINT N'';
PRINT N'=========================================================================================';
PRINT N'KỊCH BẢN 4: TÌM KIẾM THEO TỪ KHÓA BÌNH LUẬN HOẶC TÊN NGƯỜI DÙNG (@search = N''violator'')';
PRINT N'=========================================================================================';

EXEC sp_GetReportedReviews 
    @status = 'ALL', 
    @time_range = 'all', 
    @search = N'violator';

PRINT N'-> KẾT QUẢ 4: Lọc chính xác các đánh giá khớp với từ khóa tìm kiếm.';
GO


-- -----------------------------------------------------------------------------------------
-- BƯỚC CLEANUP: DỌN DẸP DỮ LIỆU TEST
-- -----------------------------------------------------------------------------------------
PRINT N'';
PRINT N'-----------------------------------------------------------------------------------------';
PRINT N'DỌN DẸP DỮ LIỆU TEST (CLEANUP)';
PRINT N'-----------------------------------------------------------------------------------------';

DECLARE @ViolatorId INT = (SELECT user_id FROM Users WHERE email = 'violator_list@gamefit.vn');
IF @ViolatorId IS NOT NULL
BEGIN
    DELETE FROM Reviews WHERE user_id = @ViolatorId;
END;

DELETE FROM Users WHERE email IN ('violator_list@gamefit.vn', 'reporter_list@gamefit.vn');
PRINT N'-> Đã dọn dẹp các bản ghi test.';
GO

PRINT N'=========================================================================================';
PRINT N'HOÀN TẤT DEMO SP: sp_GetReportedReviews';
PRINT N'=========================================================================================';
GO
