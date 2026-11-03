-- =========================================================================================
-- FILE DEMO: STORED PROCEDURE [dbo].[sp_MarkNotificationAsRead]
-- THƯ MỤC: e:\Antigravity IDE\gamefit\gamefit-db\demo_script\
-- MỤC ĐÍCH: KIỂM THỬ THỦ TỤC ĐÁNH DẤU THÔNG BÁO LÀ ĐÃ ĐỌC (is_read = 1)
-- =========================================================================================

USE gamefit_db;
GO

PRINT N'=========================================================================================';
PRINT N'BẮT ĐẦU CHẠY DEMO SP: sp_MarkNotificationAsRead';
PRINT N'=========================================================================================';
GO

-- -----------------------------------------------------------------------------------------
-- BƯỚC 0: CHUẨN BỊ DỮ LIỆU TEST (SETUP)
-- -----------------------------------------------------------------------------------------
PRINT N'-----------------------------------------------------------------------------------------';
PRINT N'BƯỚC 0: CHUẨN BỊ DỮ LIỆU TEST';
PRINT N'-----------------------------------------------------------------------------------------';

-- 1. Lấy 1 User có sẵn trong hệ thống (hoặc tạo mới nếu chưa có)
DECLARE @UserId INT;
SELECT TOP 1 @UserId = user_id FROM Users;

IF @UserId IS NULL
BEGIN
    INSERT INTO Users (username, email, password, role)
    VALUES ('test_markread_user', 'testmarkread@gamefit.vn', 'hash_pass', 'User');
    SET @UserId = SCOPE_IDENTITY();
END;

-- 2. Dọn dẹp thông báo demo cũ của user này
DELETE FROM Notifications 
WHERE user_id = @UserId AND title LIKE N'Demo MarkRead%';

-- 3. Tạo mẫu: 3 thông báo đều CHƯA ĐỌC (is_read = 0)
INSERT INTO Notifications (user_id, title, message, type, target_url, is_read, created_at)
VALUES 
    (@UserId, N'Demo MarkRead 1', N'Thông báo test đọc 1', 'SYSTEM', '/html/home.html', 0, DATEADD(MINUTE, -15, GETDATE())),
    (@UserId, N'Demo MarkRead 2', N'Thông báo test đọc 2', 'COMMUNITY', '/html/forum.html', 0, DATEADD(MINUTE, -10, GETDATE())),
    (@UserId, N'Demo MarkRead 3', N'Thông báo test đọc 3', 'SECURITY', '/html/profile.html', 0, GETDATE());

PRINT N'-> Đã khởi tạo 3 thông báo CHƯA ĐỌC (is_read = 0) cho User ID = ' + CAST(@UserId AS VARCHAR(10));

-- Xem trạng thái ban đầu của cả 3 thông báo
SELECT notification_id, title, is_read, N'CHƯA ĐỌC' AS TrangThai 
FROM Notifications 
WHERE user_id = @UserId AND title LIKE N'Demo MarkRead%';
GO


-- =========================================================================================
-- KỊCH BẢN 1: ĐÁNH DẤU 1 THÔNG BÁO CỤ THỂ LÀ ĐÃ ĐỌC (@notification_id IS NOT NULL)
-- Ý nghĩa: Khi người dùng nhấp chuột vào 1 thông báo duy nhất trong danh sách
-- =========================================================================================
PRINT N'';
PRINT N'=========================================================================================';
PRINT N'KỊCH BẢN 1: ĐÁNH DẤU 1 THÔNG BÁO DUY NHẤT LÀ ĐÃ ĐỌC';
PRINT N'=========================================================================================';

DECLARE @UserId INT = (SELECT TOP 1 user_id FROM Users);
DECLARE @TargetId INT;

-- Lấy ID của thông báo "Demo MarkRead 1"
SELECT TOP 1 @TargetId = notification_id 
FROM Notifications 
WHERE user_id = @UserId AND title = N'Demo MarkRead 1';

PRINT N'[1.1] Gọi sp_MarkNotificationAsRead cho Notification ID = ' + CAST(@TargetId AS VARCHAR(10)) + N'...';
EXEC sp_MarkNotificationAsRead @user_id = @UserId, @notification_id = @TargetId;

PRINT N'[1.2] Kiểm tra lại trạng thái các thông báo trong bảng:';
SELECT notification_id, title, is_read, 
       CASE WHEN is_read = 1 THEN N'ĐÃ ĐỌC' ELSE N'CHƯA ĐỌC' END AS TrangThai
FROM Notifications 
WHERE user_id = @UserId AND title LIKE N'Demo MarkRead%';

PRINT N'-> KẾT QUẢ 1: Chỉ duy nhất thông báo ID ' + CAST(@TargetId AS VARCHAR(10)) + N' chuyển sang is_read = 1 (affected_rows = 1). Các thông báo khác vẫn giữ nguyên is_read = 0.';
GO


-- =========================================================================================
-- KỊCH BẢN 2: ĐÁNH DẤU TẤT CẢ THÔNG BÁO CÒN LẠI LÀ ĐÃ ĐỌC (@notification_id = NULL)
-- Ý nghĩa: Khi người dùng bấm nút "Đánh dấu tất cả là đã đọc" trên giao diện
-- =========================================================================================
PRINT N'';
PRINT N'=========================================================================================';
PRINT N'KỊCH BẢN 2: ĐÁNH DẤU TẤT CẢ THÔNG BÁO LÀ ĐÃ ĐỌC (@notification_id = NULL)';
PRINT N'=========================================================================================';

DECLARE @UserId INT = (SELECT TOP 1 user_id FROM Users);

PRINT N'[2.1] Gọi sp_MarkNotificationAsRead với @notification_id = NULL...';
EXEC sp_MarkNotificationAsRead @user_id = @UserId, @notification_id = NULL;

PRINT N'[2.2] Kiểm tra lại trạng thái tất cả thông báo trong bảng:';
SELECT notification_id, title, is_read, 
       CASE WHEN is_read = 1 THEN N'ĐÃ ĐỌC' ELSE N'CHƯA ĐỌC' END AS TrangThai
FROM Notifications 
WHERE user_id = @UserId AND title LIKE N'Demo MarkRead%';

PRINT N'-> KẾT QUẢ 2: Toàn bộ thông báo còn lại của user đều đã được cập nhật thành is_read = 1.';
GO


-- =========================================================================================
-- KỊCH BẢN 3: THỰC THI LẶP LẠI KHI TẤT CẢ ĐÃ ĐƯỢC ĐỌC RỒI
-- Ý nghĩa: Kiểm tra tính an toàn (Idempotency), thủ tục trả về affected_rows = 0 mà không báo lỗi
-- =========================================================================================
PRINT N'';
PRINT N'=========================================================================================';
PRINT N'KỊCH BẢN 3: GỌI LẠI KHI KHÔNG CÒN THÔNG BÁO NÀO CHƯA ĐỌC';
PRINT N'=========================================================================================';

DECLARE @UserId INT = (SELECT TOP 1 user_id FROM Users);

-- Gọi lại
EXEC sp_MarkNotificationAsRead @user_id = @UserId, @notification_id = NULL;

PRINT N'-> KẾT QUẢ 3: Trả về affected_rows = 0 an toàn vì không có thông báo nào cần cập nhật nữa.';
GO


-- =========================================================================================
-- BƯỚC DỌN DẸP DỮ LIỆU TEST (CLEANUP)
-- =========================================================================================
PRINT N'';
PRINT N'-----------------------------------------------------------------------------------------';
PRINT N'DỌN DẸP DỮ LIỆU DEMO ĐỂ GIỮ SẠCH DATABASE';
PRINT N'-----------------------------------------------------------------------------------------';

DECLARE @UserId INT = (SELECT TOP 1 user_id FROM Users);

DELETE FROM Notifications 
WHERE user_id = @UserId AND title LIKE N'Demo MarkRead%';

PRINT N'==> ĐÃ DỌN DẸP SẠCH DỮ LIỆU TEST. DATABASE ĐÃ TRỞ VỀ TRẠNG THÁI NGUYÊN BẢN!';
PRINT N'=========================================================================================';
GO
