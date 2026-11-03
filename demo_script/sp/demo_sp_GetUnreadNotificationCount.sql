-- =========================================================================================
-- FILE DEMO: STORED PROCEDURE [dbo].[sp_GetUnreadNotificationCount]
-- THƯ MỤC: e:\Antigravity IDE\gamefit\gamefit-db\demo_script\
-- MỤC ĐÍCH: KIỂM THỬ THỦ TỤC ĐẾM SỐ THÔNG BÁO CHƯA ĐỌC (HIỆN BADGE TRÊN QUẢ CHUÔNG)
-- =========================================================================================

USE gamefit_db;
GO

PRINT N'=========================================================================================';
PRINT N'BẮT ĐẦU CHẠY DEMO SP: sp_GetUnreadNotificationCount';
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
    VALUES ('test_unread_user', 'testunread@gamefit.vn', 'hash_pass', 'User');
    SET @UserId = SCOPE_IDENTITY();
END;

-- 2. Dọn dẹp thông báo demo cũ của user này
DELETE FROM Notifications 
WHERE user_id = @UserId AND title LIKE N'Demo UnreadCount%';

-- 3. Tạo mẫu: 3 thông báo CHƯA ĐỌC (is_read = 0) và 1 thông báo ĐÃ ĐỌC (is_read = 1)
INSERT INTO Notifications (user_id, title, message, type, target_url, is_read, created_at)
VALUES 
    (@UserId, N'Demo UnreadCount 1', N'Thông báo chưa đọc 1', 'SYSTEM', '/html/home.html', 0, DATEADD(MINUTE, -20, GETDATE())),
    (@UserId, N'Demo UnreadCount 2', N'Thông báo chưa đọc 2', 'SYSTEM', '/html/home.html', 0, DATEADD(MINUTE, -10, GETDATE())),
    (@UserId, N'Demo UnreadCount 3', N'Thông báo chưa đọc 3', 'COMMUNITY', '/html/home.html', 0, GETDATE()),
    (@UserId, N'Demo UnreadCount 4', N'Thông báo đã đọc cũ', 'SYSTEM', '/html/home.html', 1, DATEADD(HOUR, -1, GETDATE()));

PRINT N'-> Đã khởi tạo 3 thông báo chưa đọc và 1 thông báo đã đọc cho User ID = ' + CAST(@UserId AS VARCHAR(10));
GO


-- =========================================================================================
-- KỊCH BẢN 1: ĐẾM SỐ THÔNG BÁO CHƯA ĐỌC CỦA NGƯỜI DÙNG (KỲ VỌNG: 3)
-- Ý nghĩa: Hệ thống web gọi SP này để lấy con số hiển thị lên góc quả chuông đỏ
-- =========================================================================================
PRINT N'';
PRINT N'=========================================================================================';
PRINT N'KỊCH BẢN 1: GỌI sp_GetUnreadNotificationCount LẦN ĐẦU (KỲ VỌNG: 3)';
PRINT N'=========================================================================================';

DECLARE @UserId INT = (SELECT TOP 1 user_id FROM Users);

-- 1. Gọi Stored Procedure
EXEC sp_GetUnreadNotificationCount @user_id = @UserId;

-- 2. Đối chiếu kiểm chứng bằng câu lệnh SELECT COUNT trực tiếp
SELECT COUNT(*) AS [DoiChieu_TrucTiep_ChuaDoc]
FROM dbo.Notifications
WHERE user_id = @UserId AND is_read = 0;

PRINT N'-> KẾT QUẢ 1: Số lượng trả về khớp chính xác với số lượng thông báo có is_read = 0.';
GO


-- =========================================================================================
-- KỊCH BẢN 2: THỬ NGHIỆM KHI NGƯỜI DÙNG VỪA ĐỌC 1 THÔNG BÁO (KỲ VỌNG GIẢM XUỐNG CÒN: 2)
-- =========================================================================================
PRINT N'';
PRINT N'=========================================================================================';
PRINT N'KỊCH BẢN 2: CẬP NHẬT 1 THÔNG BÁO THÀNH ĐÃ ĐỌC -> GỌI LẠI SP ĐỂ KIỂM CHỨNG';
PRINT N'=========================================================================================';

DECLARE @UserId INT = (SELECT TOP 1 user_id FROM Users);

-- Giả lập người dùng vừa click đọc thông báo 1
UPDATE TOP (1) Notifications
SET is_read = 1
WHERE user_id = @UserId AND title = N'Demo UnreadCount 1';

PRINT N'[2.1] Đã chuyển 1 thông báo sang trạng thái is_read = 1.';
PRINT N'[2.2] Gọi lại sp_GetUnreadNotificationCount:';

EXEC sp_GetUnreadNotificationCount @user_id = @UserId;

PRINT N'-> KẾT QUẢ 2: Số lượng chưa đọc tự động giảm từ 3 xuống còn 2.';
GO


-- =========================================================================================
-- KỊCH BẢN 3: KIỂM THỬ VỚI USER KHÔNG CÓ THÔNG BÁO NÀO (KỲ VỌNG: 0)
-- Ý nghĩa: Đảm bảo thủ tục chạy an toàn, trả về 0 chứ không bị lỗi NULL hay văng lỗi runtime
-- =========================================================================================
PRINT N'';
PRINT N'=========================================================================================';
PRINT N'KỊCH BẢN 3: GỌI VỚI USER KHÔNG CÓ THÔNG BÁO NÀO (ID ẢO: 999999)';
PRINT N'=========================================================================================';

EXEC sp_GetUnreadNotificationCount @user_id = 999999;

PRINT N'-> KẾT QUẢ 3: Trả về unread_count = 0 an toàn tuyệt đối.';
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
WHERE user_id = @UserId AND title LIKE N'Demo UnreadCount%';

PRINT N'==> ĐÃ DỌN DẸP SẠCH DỮ LIỆU TEST. DATABASE ĐÃ TRỞ VỀ TRẠNG THÁI NGUYÊN BẢN!';
PRINT N'=========================================================================================';
GO
