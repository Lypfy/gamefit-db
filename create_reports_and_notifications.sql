-- tạo 2 bảng mới: Review_Reports và Notifications
USE gamefit_db;
GO

-- 1. BẢNG Review_Reports (Lưu chi tiết từng lượt báo cáo bình luận)
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Review_Reports')
BEGIN
    CREATE TABLE Review_Reports (
        report_id INT IDENTITY(1,1) PRIMARY KEY,
        review_id INT NOT NULL,                          -- ID bình luận bị tố cáo (FK)
        user_id INT NOT NULL,                            -- ID người gửi tố cáo (FK)
        report_reason NVARCHAR(255) NOT NULL,            -- Lý do vi phạm chính
        report_detail NVARCHAR(500) NULL,                -- Ghi chú chi tiết bổ sung (tùy chọn)
        reported_at DATETIME DEFAULT DATEADD(HOUR, 7, GETUTCDATE()), -- Múi giờ UTC+7 Việt Nam

        CONSTRAINT FK_ReviewReports_Reviews FOREIGN KEY (review_id) REFERENCES dbo.Reviews(review_id) ON DELETE CASCADE,
        CONSTRAINT FK_ReviewReports_Users FOREIGN KEY (user_id) REFERENCES dbo.Users(user_id),
        
        -- Ràng buộc chống spam: Mỗi tài khoản chỉ được báo cáo 1 bình luận DUY NHẤT 1 LẦN
        CONSTRAINT UQ_ReviewReports_User_Review UNIQUE (user_id, review_id)
    );
    PRINT N'Đã tạo thành công bảng Review_Reports!';
END
ELSE
BEGIN
    PRINT N'Bảng Review_Reports đã tồn tại.';
END
GO

-- 2. BẢNG Notifications (Hộp thư thông báo người dùng)
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Notifications')
BEGIN
    CREATE TABLE Notifications (
        notification_id INT IDENTITY(1,1) PRIMARY KEY,
        user_id INT NOT NULL,                            -- Người nhận thông báo (FK)
        title NVARCHAR(150) NOT NULL,                    -- Tiêu đề ngắn gọn
        message NVARCHAR(500) NOT NULL,                  -- Nội dung chi tiết
        type VARCHAR(30) NOT NULL DEFAULT 'SYSTEM',      -- REVIEW_HIDDEN, REPORT_RESULT, SYSTEM
        target_url VARCHAR(255) NULL,                    -- Đường dẫn liên kết khi nhấn vào thông báo
        is_read BIT NOT NULL DEFAULT 0,                   -- 0: Chưa đọc, 1: Đã đọc
        created_at DATETIME DEFAULT DATEADD(HOUR, 7, GETUTCDATE()), -- Múi giờ UTC+7 Việt Nam

        CONSTRAINT FK_Notifications_Users FOREIGN KEY (user_id) REFERENCES dbo.Users(user_id) ON DELETE CASCADE
    );
    PRINT N'Đã tạo thành công bảng Notifications!';
END
ELSE
BEGIN
    PRINT N'Bảng Notifications đã tồn tại.';
END
GO
