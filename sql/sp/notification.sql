-- lấy danh sách thông báo của người dùng
CREATE OR ALTER PROCEDURE sp_GetUserNotifications
    @user_id INT,
    @limit INT = 20
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP (@limit)
        notification_id,
        user_id,
        title,
        message,
        type,
        target_url,
        is_read,
        created_at
    FROM dbo.Notifications
    WHERE user_id = @user_id
    ORDER BY created_at DESC;
END;
GO

-- đếm số lượng thông báo chưa đọc của người dùng
CREATE OR ALTER PROCEDURE sp_GetUnreadNotificationCount
    @user_id INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT COUNT(*) AS unread_count
    FROM dbo.Notifications
    WHERE user_id = @user_id AND is_read = 0;
END;
GO

-- đánh dấu thông báo là đã đọc (1 thông báo hoặc tất cả)
CREATE OR ALTER PROCEDURE sp_MarkNotificationAsRead
    @user_id INT,
    @notification_id INT = NULL -- tất cả thông báo đã đọc
AS
BEGIN
    SET NOCOUNT ON;

    IF @notification_id IS NOT NULL
    BEGIN
        UPDATE dbo.Notifications
        SET is_read = 1
        WHERE notification_id = @notification_id AND user_id = @user_id;
    END
    ELSE
    BEGIN
        UPDATE dbo.Notifications
        SET is_read = 1
        WHERE user_id = @user_id AND is_read = 0;
    END

    SELECT @@ROWCOUNT AS affected_rows;
END;
GO

-- tự tạo thông báo (do hệ thống hoặc admin tạo)
CREATE OR ALTER PROCEDURE sp_CreateNotification
    @user_id INT,
    @title NVARCHAR(150),
    @message NVARCHAR(500),
    @type VARCHAR(30) = 'SYSTEM',
    @target_url VARCHAR(255) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO dbo.Notifications (user_id, title, message, type, target_url, is_read, created_at)
    VALUES (@user_id, @title, @message, @type, @target_url, 0, DATEADD(HOUR, 7, GETUTCDATE()));

    SELECT SCOPE_IDENTITY() AS notification_id;
END;
GO
