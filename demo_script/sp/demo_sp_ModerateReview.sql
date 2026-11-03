-- =========================================================================================
-- FILE DEMO: STORED PROCEDURE [dbo].[sp_ModerateReview]
-- THƯ MỤC: e:\Antigravity IDE\gamefit\gamefit-db\demo_script\sp\
-- MỤC ĐÍCH: KIỂM THỬ THỦ TỤC XỬ LÝ KIỂM DUYỆT (ẨN BÌNH LUẬN / BỎ QUA BÁO CÁO & TỰ ĐỘNG BẮN THÔNG BÁO)
-- PHỤC VỤ: CHẠY TRỰC TIẾP TRÊN SSMS & BÁO CÁO VẤN ĐÁP ĐỒ ÁN GAMEFIT
-- =========================================================================================

USE gamefit_db;
GO

PRINT N'=========================================================================================';
PRINT N'BẮT ĐẦU CHẠY DEMO SP: sp_ModerateReview';
PRINT N'=========================================================================================';
GO

-- -----------------------------------------------------------------------------------------
-- BƯỚC 0: CHUẨN BỊ DỮ LIỆU TEST (SETUP)
-- -----------------------------------------------------------------------------------------
PRINT N'-----------------------------------------------------------------------------------------';
PRINT N'BƯỚC 0: CHUẨN BỊ DỮ LIỆU TEST (TẠO REVIEW VÀ 2 NGƯỜI BÁO CÁO)';
PRINT N'-----------------------------------------------------------------------------------------';

-- 1. Lấy 1 Game hợp lệ
DECLARE @GameId INT = (SELECT TOP 1 game_id FROM Games WHERE is_active = 1);

-- 2. Tạo User vi phạm (Violator)
DECLARE @ViolatorId INT;
SELECT @ViolatorId = user_id FROM Users WHERE email = 'violator_mod@gamefit.vn';
IF @ViolatorId IS NULL
BEGIN
    INSERT INTO Users (user_name, email, password, role, status)
    VALUES ('violator_mod_user', 'violator_mod@gamefit.vn', 'hash_pass', 'User', 'Active');
    SET @ViolatorId = SCOPE_IDENTITY();
END;

-- 3. Tạo 2 User gửi báo cáo (Reporter 1 & Reporter 2)
DECLARE @Reporter1 INT, @Reporter2 INT;

SELECT @Reporter1 = user_id FROM Users WHERE email = 'reporter1_mod@gamefit.vn';
IF @Reporter1 IS NULL
BEGIN
    INSERT INTO Users (user_name, email, password, role, status)
    VALUES ('reporter1_mod', 'reporter1_mod@gamefit.vn', 'hash_pass', 'User', 'Active');
    SET @Reporter1 = SCOPE_IDENTITY();
END;

SELECT @Reporter2 = user_id FROM Users WHERE email = 'reporter2_mod@gamefit.vn';
IF @Reporter2 IS NULL
BEGIN
    INSERT INTO Users (user_name, email, password, role, status)
    VALUES ('reporter2_mod', 'reporter2_mod@gamefit.vn', 'hash_pass', 'User', 'Active');
    SET @Reporter2 = SCOPE_IDENTITY();
END;

-- 4. Dọn dẹp dữ liệu cũ nếu còn sót
DELETE FROM Notifications WHERE user_id IN (@ViolatorId, @Reporter1, @Reporter2);
DELETE FROM Review_Reports WHERE user_id IN (@Reporter1, @Reporter2);
DELETE FROM Reviews WHERE user_id = @ViolatorId;

-- 5. Tạo Review 1 (sẽ dùng để test HIDE - Ẩn bình luận)
INSERT INTO Reviews (user_id, game_id, rating, comment, is_hidden, report_status, created_at)
VALUES (@ViolatorId, @GameId, 1, N'Bình luận vi phạm: Link lừa đảo nạp thẻ gamefit-scam.net', 0, 'PENDING', GETDATE());
DECLARE @RevHide_Id INT = SCOPE_IDENTITY();

-- Thêm 2 báo cáo từ 2 user khác nhau cho Review 1
INSERT INTO Review_Reports (review_id, user_id, report_reason, report_detail, reported_at)
VALUES 
    (@RevHide_Id, @Reporter1, N'Lừa đảo / Phishing', N'Quảng cáo web scam nạp thẻ', DATEADD(HOUR, 7, GETUTCDATE())),
    (@RevHide_Id, @Reporter2, N'Spam', N'Spam liên tục nhiều lần', DATEADD(HOUR, 7, GETUTCDATE()));

-- 6. Tạo Review 2 (sẽ dùng để test DISMISS - Bỏ qua báo cáo)
-- Để tránh vi phạm UNIQUE (user_id, game_id), chọn game khác hoặc cập nhật sau khi test Review 1
PRINT N'-> Đã khởi tạo thành công dữ liệu test kiểm duyệt:';
PRINT N'   + Game ID      : ' + CAST(@GameId AS VARCHAR(10));
PRINT N'   + Review ID    : ' + CAST(@RevHide_Id AS VARCHAR(10));
PRINT N'   + Violator ID  : ' + CAST(@ViolatorId AS VARCHAR(10));
PRINT N'   + Reporter 1 ID: ' + CAST(@Reporter1 AS VARCHAR(10));
PRINT N'   + Reporter 2 ID: ' + CAST(@Reporter2 AS VARCHAR(10));
GO


-- =========================================================================================
-- KỊCH BẢN 1: ADMIN QUYẾT ĐỊNH ẨN BÌNH LUẬN VI PHẠM (@action = 'HIDE')
-- Ý nghĩa & Điểm cộng vấn đáp:
--   1. Cập nhật Reviews: is_hidden = 1, report_status = 'HIDDEN'
--   2. Tự động bắn thông báo loại REVIEW_HIDDEN cho người viết review
--   3. Tự động bắn thông báo loại REPORT_RESULT cảm ơn TẤT CẢ những người đã báo cáo bài này
-- =========================================================================================
PRINT N'';
PRINT N'=========================================================================================';
PRINT N'KỊCH BẢN 1: ADMIN CHỌN HÀNH ĐỘNG HIDE (ẨN BÌNH LUẬN & GỬI THÔNG BÁO TỰ ĐỘNG)';
PRINT N'=========================================================================================';

DECLARE @ViolatorId INT = (SELECT user_id FROM Users WHERE email = 'violator_mod@gamefit.vn');
DECLARE @Reporter1 INT = (SELECT user_id FROM Users WHERE email = 'reporter1_mod@gamefit.vn');
DECLARE @Reporter2 INT = (SELECT user_id FROM Users WHERE email = 'reporter2_mod@gamefit.vn');
DECLARE @ReviewId INT = (SELECT TOP 1 review_id FROM Reviews WHERE user_id = @ViolatorId);

PRINT N'[1.1] Trạng thái Review trước khi kiểm duyệt:';
SELECT review_id, user_id, comment, is_hidden, report_status
FROM Reviews
WHERE review_id = @ReviewId;

-- Admin thực thi quyết định HIDE
PRINT N'-> Admin gọi EXEC sp_ModerateReview @review_id = ' + CAST(@ReviewId AS VARCHAR(10)) + N', @action = ''HIDE'';';
EXEC sp_ModerateReview @review_id = @ReviewId, @action = 'HIDE';

PRINT N'[1.2] Trạng thái Review sau khi Admin chọn HIDE:';
SELECT review_id, user_id, comment, is_hidden, report_status
FROM Reviews
WHERE review_id = @ReviewId;

PRINT N'[1.3] Kiểm tra các thông báo tự động được sinh ra trong bảng Notifications:';
SELECT notification_id, user_id, title, message, type, target_url, created_at
FROM Notifications
WHERE user_id IN (@ViolatorId, @Reporter1, @Reporter2)
ORDER BY created_at DESC;

PRINT N'-> KẾT QUẢ 1:';
PRINT N'   + Review đã bị ẩn (is_hidden = 1, report_status = HIDDEN).';
PRINT N'   + Người vi phạm nhận thông báo REVIEW_HIDDEN cảnh báo bài viết bị ẩn.';
PRINT N'   + Cả 2 người gửi báo cáo đều nhận được thông báo REPORT_RESULT cảm ơn phản ánh!';
GO


-- =========================================================================================
-- KỊCH BẢN 2: ADMIN BỎ QUA BÁO CÁO (@action = 'DISMISS')
-- Ý nghĩa: Đánh giá bình thường, người dùng báo cáo sai -> Admin hủy báo cáo, giữ bình luận hiển thị
-- =========================================================================================
PRINT N'';
PRINT N'=========================================================================================';
PRINT N'KỊCH BẢN 2: ADMIN CHỌN HÀNH ĐỘNG DISMISS (BỎ QUA BÁO CÁO)';
PRINT N'=========================================================================================';

DECLARE @ViolatorId INT = (SELECT user_id FROM Users WHERE email = 'violator_mod@gamefit.vn');
DECLARE @ReviewId INT = (SELECT TOP 1 review_id FROM Reviews WHERE user_id = @ViolatorId);

-- Admin xem xét lại và quyết định DISMISS
PRINT N'-> Admin gọi EXEC sp_ModerateReview @review_id = ' + CAST(@ReviewId AS VARCHAR(10)) + N', @action = ''DISMISS'';';
EXEC sp_ModerateReview @review_id = @ReviewId, @action = 'DISMISS';

PRINT N'[2.1] Trạng thái Review sau khi Admin chọn DISMISS:';
SELECT review_id, user_id, comment, is_hidden, report_status
FROM Reviews
WHERE review_id = @ReviewId;

PRINT N'-> KẾT QUẢ 2: is_hidden = 0 và report_status = DISMISSED (Bình luận vẫn được hiển thị bình thường).';
GO


-- =========================================================================================
-- KỊCH BẢN 3: VALIDATION - HÀNH ĐỘNG KHÔNG HỢP LỆ (@action KHÁC 'HIDE' VÀ 'DISMISS')
-- Ý nghĩa: Chỉ cho phép 2 hành động chuẩn hóa HIDE hoặc DISMISS
-- =========================================================================================
PRINT N'';
PRINT N'=========================================================================================';
PRINT N'KỊCH BẢN 3: BẮT LỖI KHI TRUYỀN HÀNH ĐỘNG SAI (VÍ DỤ: @action = ''BAN'')';
PRINT N'=========================================================================================';

DECLARE @ViolatorId INT = (SELECT user_id FROM Users WHERE email = 'violator_mod@gamefit.vn');
DECLARE @ReviewId INT = (SELECT TOP 1 review_id FROM Reviews WHERE user_id = @ViolatorId);

BEGIN TRY
    PRINT N'Thử gọi với action = ''BAN''...';
    EXEC sp_ModerateReview @review_id = @ReviewId, @action = 'BAN';

    PRINT N'LỖI TEST: Không được phép chấp nhận action này!';
END TRY
BEGIN CATCH
    PRINT N'-> KẾT QUẢ 3 (Bắt lỗi chuẩn): ' + ERROR_MESSAGE();
END CATCH;
GO


-- =========================================================================================
-- KỊCH BẢN 4: VALIDATION - REVIEW KHÔNG TỒN TẠI (ID ẢO = 999999)
-- Ý nghĩa: Kiểm tra ràng buộc tồn tại bản ghi cần kiểm duyệt
-- =========================================================================================
PRINT N'';
PRINT N'=========================================================================================';
PRINT N'KỊCH BẢN 4: BẮT LỖI REVIEW KHÔNG TỒN TẠI (ID ẢO = 999999)';
PRINT N'=========================================================================================';

BEGIN TRY
    PRINT N'Thử kiểm duyệt Review ID = 999999...';
    EXEC sp_ModerateReview @review_id = 999999, @action = 'HIDE';

    PRINT N'LỖI TEST: Không được phép thành công!';
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

DECLARE @ViolatorId INT = (SELECT user_id FROM Users WHERE email = 'violator_mod@gamefit.vn');
DECLARE @Reporter1 INT = (SELECT user_id FROM Users WHERE email = 'reporter1_mod@gamefit.vn');
DECLARE @Reporter2 INT = (SELECT user_id FROM Users WHERE email = 'reporter2_mod@gamefit.vn');

IF @ViolatorId IS NOT NULL
BEGIN
    DELETE FROM Notifications WHERE user_id IN (@ViolatorId, @Reporter1, @Reporter2);
    DELETE FROM Review_Reports WHERE user_id IN (@Reporter1, @Reporter2);
    DELETE FROM Reviews WHERE user_id = @ViolatorId;
END;

DELETE FROM Users WHERE email IN ('violator_mod@gamefit.vn', 'reporter1_mod@gamefit.vn', 'reporter2_mod@gamefit.vn');
PRINT N'-> Đã dọn dẹp các bản ghi test trong Notifications, Review_Reports, Reviews và Users.';
GO

PRINT N'=========================================================================================';
PRINT N'HOÀN TẤT DEMO SP: sp_ModerateReview';
PRINT N'=========================================================================================';
GO
