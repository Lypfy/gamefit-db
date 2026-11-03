-- =========================================================================================
-- FILE DEMO: STORED PROCEDURE [dbo].[sp_GetReviewReportDetails]
-- THƯ MỤC: e:\Antigravity IDE\gamefit\gamefit-db\demo_script\sp\
-- MỤC ĐÍCH: KIỂM THỬ THỦ TỤC XEM CHI TIẾT CÁC LƯỢT BÁO CÁO CỦA MỘT REVIEW (DÀNH CHO MODAL ADMIN)
-- PHỤC VỤ: CHẠY TRỰC TIẾP TRÊN SSMS & BÁO CÁO VẤN ĐÁP ĐỒ ÁN GAMEFIT
-- =========================================================================================

USE gamefit_db;
GO

PRINT N'=========================================================================================';
PRINT N'BẮT ĐẦU CHẠY DEMO SP: sp_GetReviewReportDetails';
PRINT N'=========================================================================================';
GO

-- -----------------------------------------------------------------------------------------
-- BƯỚC 0: CHUẨN BỊ DỮ LIỆU TEST (SETUP 1 REVIEW BỊ NHIỀU NGƯỜI BÁO CÁO)
-- -----------------------------------------------------------------------------------------
PRINT N'-----------------------------------------------------------------------------------------';
PRINT N'BƯỚC 0: CHUẨN BỊ DỮ LIỆU TEST';
PRINT N'-----------------------------------------------------------------------------------------';

-- 1. Lấy 1 Game hợp lệ
DECLARE @GameId INT = (SELECT TOP 1 game_id FROM Games WHERE is_active = 1);

-- 2. Tạo User viết đánh giá (Violator)
DECLARE @ViolatorId INT;
SELECT @ViolatorId = user_id FROM Users WHERE email = 'violator_detail@gamefit.vn';
IF @ViolatorId IS NULL
BEGIN
    INSERT INTO Users (user_name, email, password, role, status)
    VALUES ('author_toxic', 'violator_detail@gamefit.vn', 'hash_pass', 'User', 'Active');
    SET @ViolatorId = SCOPE_IDENTITY();
END;

-- 3. Tạo 2 User gửi báo cáo (Reporter A & Reporter B)
DECLARE @ReporterA INT, @ReporterB INT;

SELECT @ReporterA = user_id FROM Users WHERE email = 'reporter_a@gamefit.vn';
IF @ReporterA IS NULL
BEGIN
    INSERT INTO Users (user_name, email, password, role, status)
    VALUES ('reporter_alice', 'reporter_a@gamefit.vn', 'hash_pass', 'User', 'Active');
    SET @ReporterA = SCOPE_IDENTITY();
END;

SELECT @ReporterB = user_id FROM Users WHERE email = 'reporter_b@gamefit.vn';
IF @ReporterB IS NULL
BEGIN
    INSERT INTO Users (user_name, email, password, role, status)
    VALUES ('reporter_bob', 'reporter_b@gamefit.vn', 'hash_pass', 'User', 'Active');
    SET @ReporterB = SCOPE_IDENTITY();
END;

-- 4. Dọn dẹp dữ liệu cũ nếu có
DELETE FROM Review_Reports WHERE user_id IN (@ReporterA, @ReporterB);
DELETE FROM Reviews WHERE user_id = @ViolatorId;

-- 5. Tạo bài review vi phạm
INSERT INTO Reviews (user_id, game_id, rating, comment, is_hidden, report_status, created_at)
VALUES (@ViolatorId, @GameId, 1, N'Bài review chứa từ ngữ thô tục xúc phạm và link độc hại.', 0, 'PENDING', GETDATE());
DECLARE @ReviewId INT = SCOPE_IDENTITY();

-- 6. Thêm 2 báo cáo chi tiết từ 2 người dùng khác nhau ở 2 thời điểm khác nhau
INSERT INTO Review_Reports (review_id, user_id, report_reason, report_detail, reported_at)
VALUES 
    (@ReviewId, @ReporterA, N'Ngôn từ thô tục', N'Người này xúc phạm các thành viên khác trong bình luận.', DATEADD(MINUTE, -20, DATEADD(HOUR, 7, GETUTCDATE()))),
    (@ReviewId, @ReporterB, N'Spam / Lừa đảo', N'Chèn link giả mạo nhận giftcode game lừa đảo người dùng.', DATEADD(MINUTE, -5, DATEADD(HOUR, 7, GETUTCDATE())));

PRINT N'-> Đã khởi tạo dữ liệu mẫu:';
PRINT N'   + Game ID    : ' + CAST(@GameId AS VARCHAR(10));
PRINT N'   + Review ID  : ' + CAST(@ReviewId AS VARCHAR(10));
PRINT N'   + Báo cáo 1  : Người báo cáo = reporter_alice, Lý do = "Ngôn từ thô tục"';
PRINT N'   + Báo cáo 2  : Người báo cáo = reporter_bob,   Lý do = "Spam / Lừa đảo"';
GO


-- =========================================================================================
-- KỊCH BẢN 1: ADMIN MỞ MODAL XEM DANH SÁCH CHI TIẾT BÁO CÁO CỦA REVIEW (HAPPY PATH)
-- Ý nghĩa: Khi Admin bấm vào nút "Xem chi tiết" của 1 bài review trong bảng quản trị, 
-- hệ thống gọi sp_GetReviewReportDetails để hiển thị danh sách các người đã tố cáo kèm bằng chứng
-- =========================================================================================
PRINT N'';
PRINT N'=========================================================================================';
PRINT N'KỊCH BẢN 1: XEM TẤT CẢ CHI TIẾT BÁO CÁO CỦA REVIEW (@review_id HỢP LỆ)';
PRINT N'=========================================================================================';

DECLARE @ViolatorId INT = (SELECT user_id FROM Users WHERE email = 'violator_detail@gamefit.vn');
DECLARE @ReviewId INT = (SELECT TOP 1 review_id FROM Reviews WHERE user_id = @ViolatorId);

-- Thực thi thủ tục
EXEC sp_GetReviewReportDetails @review_id = @ReviewId;

PRINT N'-> KẾT QUẢ 1: Trả về đầy đủ 2 bản ghi báo cáo của reporter_alice và reporter_bob.';
PRINT N'   + Đã JOIN sang bảng Users để hiển thị user_name của người báo cáo (reporter_name).';
PRINT N'   + Sắp xếp giảm dần theo thời gian báo cáo (ORDER BY reported_at DESC) để xem phản ánh mới nhất.';
GO


-- =========================================================================================
-- KỊCH BẢN 2: XEM CHI TIẾT KHI REVIEW CHƯA CÓ BÁO CÁO NÀO HOẶC ID ẢO (ID = 999999)
-- Ý nghĩa: Kiểm tra độ an toàn khi không có dữ liệu, SP trả về bảng rỗng (0 dòng), không phát sinh lỗi
-- =========================================================================================
PRINT N'';
PRINT N'=========================================================================================';
PRINT N'KỊCH BẢN 2: GỌI VỚI REVIEW ID ẢO HOẶC CHƯA CÓ BÁO CÁO (@review_id = 999999)';
PRINT N'=========================================================================================';

EXEC sp_GetReviewReportDetails @review_id = 999999;

PRINT N'-> KẾT QUẢ 2: Trả về 0 dòng an toàn, cấu trúc các cột vẫn được giữ nguyên cho client render modal.';
GO


-- -----------------------------------------------------------------------------------------
-- BƯỚC CLEANUP: DỌN DẸP DỮ LIỆU TEST
-- -----------------------------------------------------------------------------------------
PRINT N'';
PRINT N'-----------------------------------------------------------------------------------------';
PRINT N'DỌN DẸP DỮ LIỆU TEST (CLEANUP)';
PRINT N'-----------------------------------------------------------------------------------------';

DECLARE @ViolatorId INT = (SELECT user_id FROM Users WHERE email = 'violator_detail@gamefit.vn');
DECLARE @ReporterA INT = (SELECT user_id FROM Users WHERE email = 'reporter_a@gamefit.vn');
DECLARE @ReporterB INT = (SELECT user_id FROM Users WHERE email = 'reporter_b@gamefit.vn');

IF @ViolatorId IS NOT NULL
BEGIN
    DELETE FROM Review_Reports WHERE user_id IN (@ReporterA, @ReporterB);
    DELETE FROM Reviews WHERE user_id = @ViolatorId;
END;

DELETE FROM Users WHERE email IN ('violator_detail@gamefit.vn', 'reporter_a@gamefit.vn', 'reporter_b@gamefit.vn');
PRINT N'-> Đã dọn dẹp các bản ghi test trong Review_Reports, Reviews và Users.';
GO

PRINT N'=========================================================================================';
PRINT N'HOÀN TẤT DEMO SP: sp_GetReviewReportDetails';
PRINT N'=========================================================================================';
GO
