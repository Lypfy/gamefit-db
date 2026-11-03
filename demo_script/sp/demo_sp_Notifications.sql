-- =========================================================================================
-- FILE DEMO VẤN ĐÁP: BỘ 3 STORED PROCEDURES QUẢN LÝ THÔNG BÁO (NOTIFICATIONS)
-- THƯ MỤC: e:\Antigravity IDE\gamefit\gamefit-db\demo_script\
-- DANH SÁCH THỦ TỤC DEMO:
--   1. sp_GetUnreadNotificationCount : Đếm số thông báo chưa đọc (hiện badge trên quả chuông)
--   2. sp_GetUserNotifications       : Lấy danh sách thông báo của người dùng (kèm phân trang limit)
--   3. sp_MarkNotificationAsRead     : Đánh dấu 1 hoặc tất cả thông báo là đã đọc
-- =========================================================================================

USE gamefit_db;
GO

PRINT N'=========================================================================================';
PRINT N'BẮT ĐẦU CHẠY DEMO QUY TRÌNH THÔNG BÁO (NOTIFICATION LIFECYCLE)';
PRINT N'=========================================================================================';
GO

-- -----------------------------------------------------------------------------------------
-- BƯỚC 0: CHUẨN BỊ DỮ LIỆU MẪU (SETUP TEST DATA)
-- -----------------------------------------------------------------------------------------
PRINT N'-----------------------------------------------------------------------------------------';
PRINT N'BƯỚC 0: KHỞI TẠO DỮ LIỆU TEST';
PRINT N'-----------------------------------------------------------------------------------------';

-- 1. Lấy 1 User có sẵn trong hệ thống (hoặc tạo mới nếu chưa có)
DECLARE @UserId INT;
SELECT TOP 1 @UserId = user_id FROM Users;

IF @UserId IS NULL
BEGIN
    INSERT INTO Users (username, email, password, role)
    VALUES ('test_notif_user', 'testnotif@gamefit.vn', 'hash_pass', 'User');
    SET @UserId = SCOPE_IDENTITY();
END;

-- 2. Dọn dẹp thông báo demo cũ nếu còn sót lại
DELETE FROM Notifications 
WHERE user_id = @UserId AND title LIKE N'Demo Notification%';

-- 3. Tạo 3 thông báo mẫu với trạng thái CHƯA ĐỌC (is_read = 0)
INSERT INTO Notifications (user_id, title, message, type, target_url, is_read, created_at)
VALUES 
    (@UserId, N'Demo Notification 1', N'Cấu hình máy của bạn đã được duyệt thành công.', 'SYSTEM', '/html/game-details.html?id=1', 0, DATEADD(MINUTE, -30, GETDATE())),
    (@UserId, N'Demo Notification 2', N'Có người đã bình luận vào bài viết của bạn.', 'COMMUNITY', '/html/forum.html', 0, DATEADD(MINUTE, -15, GETDATE())),
    (@UserId, N'Demo Notification 3', N'Cập nhật bảo mật: Đăng nhập từ thiết bị mới.', 'SECURITY', '/html/profile.html', 0, GETDATE());

PRINT N'-> Đã khởi tạo 3 thông báo mẫu chưa đọc cho User ID = ' + CAST(@UserId AS VARCHAR(10));
GO


-- =========================================================================================
-- PHẦN 1: DEMO THỦ TỤC 1: sp_GetUnreadNotificationCount
-- Mục đích: Đếm số lượng thông báo chưa đọc (is_read = 0) để hiển thị con số đỏ trên quả chuông
-- =========================================================================================
PRINT N'';
PRINT N'=========================================================================================';
PRINT N'PHẦN 1: THỰC THI sp_GetUnreadNotificationCount (ĐẾM SỐ THÔNG BÁO CHƯA ĐỌC)';
PRINT N'=========================================================================================';

DECLARE @UserId INT = (SELECT TOP 1 user_id FROM Users);

-- Gọi thủ tục
EXEC sp_GetUnreadNotificationCount @user_id = @UserId;

PRINT N'-> KẾT QUẢ 1: Trả về số lượng thông báo chưa đọc (kỳ vọng: ít nhất 3 thông báo chưa đọc).';
GO


-- =========================================================================================
-- PHẦN 2: DEMO THỦ TỤC 2: sp_GetUserNotifications
-- Mục đích: Khi người dùng nhấp vào quả chuông, dropdown mở ra và gọi SP này để lấy danh sách
-- =========================================================================================
PRINT N'';
PRINT N'=========================================================================================';
PRINT N'PHẦN 2: THỰC THI sp_GetUserNotifications (LẤY DANH SÁCH THÔNG BÁO)';
PRINT N'=========================================================================================';

DECLARE @UserId INT = (SELECT TOP 1 user_id FROM Users);

PRINT N'[2.1] Lấy tối đa 2 thông báo mới nhất (@limit = 2):';
EXEC sp_GetUserNotifications @user_id = @UserId, @limit = 2;

PRINT N'[2.2] Lấy mặc định 20 thông báo gần nhất (@limit = 20):';
EXEC sp_GetUserNotifications @user_id = @UserId, @limit = 20;

PRINT N'-> KẾT QUẢ 2: Danh sách thông báo được sắp xếp theo thời gian mới nhất (created_at DESC).';
GO


-- =========================================================================================
-- PHẦN 3: DEMO THỦ TỤC 3: sp_MarkNotificationAsRead (ĐÁNH DẤU ĐÃ ĐỌC)
-- Gồm 2 kịch bản thực tế:
--   - Kịch bản 3.1: Đánh dấu 1 thông báo cụ thể khi người dùng click vào thông báo đó
--   - Kịch bản 3.2: Đánh dấu TẤT CẢ thông báo khi người dùng bấm "Đánh dấu tất cả là đã đọc"
-- =========================================================================================
PRINT N'';
PRINT N'=========================================================================================';
PRINT N'PHẦN 3: THỰC THI sp_MarkNotificationAsRead (ĐÁNH DẤU ĐÃ ĐỌC)';
PRINT N'=========================================================================================';

DECLARE @UserId INT = (SELECT TOP 1 user_id FROM Users);
DECLARE @SingleNotifId INT;

-- Lấy ID của 1 thông báo demo bất kỳ đang chưa đọc
SELECT TOP 1 @SingleNotifId = notification_id 
FROM Notifications 
WHERE user_id = @UserId AND title = N'Demo Notification 1' AND is_read = 0;

-- -----------------------------------------------------------------------------------------
-- Kịch bản 3.1: Đánh dấu 1 thông báo duy nhất là đã đọc
-- -----------------------------------------------------------------------------------------
PRINT N'[3.1] Đánh dấu ĐÃ ĐỌC cho 1 thông báo duy nhất (Notification ID = ' + CAST(@SingleNotifId AS VARCHAR(10)) + N'):';
EXEC sp_MarkNotificationAsRead @user_id = @UserId, @notification_id = @SingleNotifId;

PRINT N'-> Kiểm tra lại số lượng chưa đọc sau khi đọc 1 thông báo:';
EXEC sp_GetUnreadNotificationCount @user_id = @UserId;

PRINT N'-> Trạng thái chi tiết thông báo đó trong bảng:';
SELECT notification_id, title, is_read, 
       CASE WHEN is_read = 1 THEN N'ĐÃ ĐỌC' ELSE N'CHƯA ĐỌC' END AS TrangThai
FROM Notifications 
WHERE notification_id = @SingleNotifId;

-- -----------------------------------------------------------------------------------------
-- Kịch bản 3.2: Đánh dấu TẤT CẢ thông báo còn lại là đã đọc (@notification_id = NULL)
-- -----------------------------------------------------------------------------------------
PRINT N'';
PRINT N'[3.2] Người dùng bấm "Đánh dấu tất cả là đã đọc" (@notification_id = NULL):';
EXEC sp_MarkNotificationAsRead @user_id = @UserId, @notification_id = NULL;

PRINT N'-> Kiểm tra lại số lượng chưa đọc sau khi đọc tất cả:';
EXEC sp_GetUnreadNotificationCount @user_id = @UserId;

PRINT N'-> Danh sách thông báo sau khi đánh dấu tất cả:';
SELECT notification_id, title, is_read, 
       CASE WHEN is_read = 1 THEN N'ĐÃ ĐỌC' ELSE N'CHƯA ĐỌC' END AS TrangThai
FROM Notifications 
WHERE user_id = @UserId AND title LIKE N'Demo Notification%';
GO


-- =========================================================================================
-- BƯỚC DỌN DẸP DỮ LIỆU DEMO (CLEANUP)
-- =========================================================================================
PRINT N'';
PRINT N'-----------------------------------------------------------------------------------------';
PRINT N'DỌN DẸP DỮ LIỆU TEST ĐỂ GIỮ SẠCH DATABASE';
PRINT N'-----------------------------------------------------------------------------------------';

DECLARE @UserId INT = (SELECT TOP 1 user_id FROM Users);

DELETE FROM Notifications 
WHERE user_id = @UserId AND title LIKE N'Demo Notification%';

PRINT N'==> ĐÃ DỌN DẸP SẠCH CÁC THÔNG BÁO TEST. CSDL ĐÃ TRỞ VỀ TRẠNG THÁI NGUYÊN BẢN!';
PRINT N'=========================================================================================';
GO
