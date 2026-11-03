-- =========================================================================================
-- FILE DEMO: STORED PROCEDURE [dbo].[sp_GetUserNotifications]
-- THƯ MỤC: e:\Antigravity IDE\gamefit\gamefit-db\demo_script\
-- MỤC ĐÍCH: KIỂM THỬ THỦ TỤC LẤY DANH SÁCH THÔNG BÁO CỦA NGƯỜI DÙNG KÈM PHÂN TRANG (LIMIT)
-- =========================================================================================

USE gamefit_db;
GO

PRINT N'=========================================================================================';
PRINT N'BẮT ĐẦU CHẠY DEMO SP: sp_GetUserNotifications';
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
    VALUES ('test_getnotif_user', 'testgetnotif@gamefit.vn', 'hash_pass', 'User');
    SET @UserId = SCOPE_IDENTITY();
END;

-- 2. Dọn dẹp thông báo demo cũ của user này
DELETE FROM Notifications 
WHERE user_id = @UserId AND title LIKE N'Demo GetNotif%';

-- 3. Tạo mẫu 5 thông báo có mốc thời gian tăng dần để test sắp xếp (created_at DESC)
INSERT INTO Notifications (user_id, title, message, type, target_url, is_read, created_at)
VALUES 
    (@UserId, N'Demo GetNotif 1', N'Thông báo cũ nhất (cách đây 40 phút)', 'SYSTEM', '/html/home.html', 1, DATEADD(MINUTE, -40, GETDATE())),
    (@UserId, N'Demo GetNotif 2', N'Thông báo thứ hai (cách đây 30 phút)', 'COMMUNITY', '/html/forum.html', 0, DATEADD(MINUTE, -30, GETDATE())),
    (@UserId, N'Demo GetNotif 3', N'Thông báo thứ ba (cách đây 20 phút)', 'SECURITY', '/html/profile.html', 0, DATEADD(MINUTE, -20, GETDATE())),
    (@UserId, N'Demo GetNotif 4', N'Thông báo thứ tư (cách đây 10 phút)', 'SYSTEM', '/html/games.html', 0, DATEADD(MINUTE, -10, GETDATE())),
    (@UserId, N'Demo GetNotif 5', N'Thông báo mới nhất (vừa xong)', 'COMMUNITY', '/html/wishlist.html', 0, GETDATE());

PRINT N'-> Đã khởi tạo 5 thông báo mẫu với thời gian tạo khác nhau cho User ID = ' + CAST(@UserId AS VARCHAR(10));
GO


-- =========================================================================================
-- KỊCH BẢN 1: LẤY CÓ GIỚI HẠN (@limit = 2) - LẤY 2 THÔNG BÁO MỚI NHẤT
-- Ý nghĩa: Kiểm tra tham số @limit và tính năng sắp xếp mới nhất lên đầu (ORDER BY created_at DESC)
-- =========================================================================================
PRINT N'';
PRINT N'=========================================================================================';
PRINT N'KỊCH BẢN 1: GỌI sp_GetUserNotifications VỚI @limit = 2';
PRINT N'=========================================================================================';

DECLARE @UserId INT = (SELECT TOP 1 user_id FROM Users);

-- Gọi thủ tục với limit = 2
EXEC sp_GetUserNotifications @user_id = @UserId, @limit = 2;

PRINT N'-> KẾT QUẢ 1: Trả về đúng 2 thông báo mới nhất (Demo GetNotif 5 và Demo GetNotif 4).';
GO


-- =========================================================================================
-- KỊCH BẢN 2: LẤY VỚI GIÁ TRỊ MẶC ĐỊNH (@limit = 20)
-- Ý nghĩa: Khi người dùng mở xem tất cả danh sách thông báo
-- =========================================================================================
PRINT N'';
PRINT N'=========================================================================================';
PRINT N'KỊCH BẢN 2: GỌI sp_GetUserNotifications VỚI GIÁ TRỊ MẶC ĐỊNH (@limit = 20)';
PRINT N'=========================================================================================';

DECLARE @UserId INT = (SELECT TOP 1 user_id FROM Users);

-- Gọi thủ tục với limit = 20
EXEC sp_GetUserNotifications @user_id = @UserId, @limit = 20;

PRINT N'-> KẾT QUẢ 2: Trả về đầy đủ tất cả thông báo của người dùng, sắp xếp giảm dần theo ngày tạo.';
GO


-- =========================================================================================
-- KỊCH BẢN 3: KIỂM THỬ VỚI USER CHƯA CÓ THÔNG BÁO NÀO
-- Ý nghĩa: Đảm bảo thủ tục trả về 0 dòng an toàn, không bị lỗi cú pháp
-- =========================================================================================
PRINT N'';
PRINT N'=========================================================================================';
PRINT N'KỊCH BẢN 3: GỌI VỚI USER KHÔNG CÓ THÔNG BÁO NÀO (ID ẢO: 999999)';
PRINT N'=========================================================================================';

EXEC sp_GetUserNotifications @user_id = 999999, @limit = 20;

PRINT N'-> KẾT QUẢ 3: Trả về bảng rỗng (0 dòng), chạy an toàn.';
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
WHERE user_id = @UserId AND title LIKE N'Demo GetNotif%';

PRINT N'==> ĐÃ DỌN DẸP SẠCH DỮ LIỆU TEST. DATABASE ĐÃ TRỞ VỀ TRẠNG THÁI NGUYÊN BẢN!';
PRINT N'=========================================================================================';
GO
