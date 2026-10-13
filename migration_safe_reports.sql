-- ===================================================================================
-- SCRIPT MIGRATION AN TOÀN: CHUẨN HÓA BÁO CÁO BÌNH LUẬN & THÔNG BÁO
-- Dự án: GameFit
-- ===================================================================================

USE gamefit_db;
GO

BEGIN TRANSACTION;
BEGIN TRY

    -- -------------------------------------------------------------------------------
    -- 1. TẠO BẢNG MỚI NẾU CHƯA CÓ
    -- -------------------------------------------------------------------------------
    IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Review_Reports')
    BEGIN
        CREATE TABLE Review_Reports (
            report_id INT IDENTITY(1,1) PRIMARY KEY,
            review_id INT NOT NULL,
            user_id INT NOT NULL,
            report_reason NVARCHAR(255) NOT NULL,
            report_detail NVARCHAR(500) NULL,
            reported_at DATETIME DEFAULT DATEADD(HOUR, 7, GETUTCDATE()),

            CONSTRAINT FK_ReviewReports_Reviews FOREIGN KEY (review_id) REFERENCES dbo.Reviews(review_id) ON DELETE CASCADE,
            CONSTRAINT FK_ReviewReports_Users FOREIGN KEY (user_id) REFERENCES dbo.Users(user_id),
            CONSTRAINT UQ_ReviewReports_User_Review UNIQUE (user_id, review_id) -- Chống Spam
        );
        PRINT N'-> Đã tạo bảng Review_Reports thành công.';
    END
    ELSE
    BEGIN
        -- Mở rộng cột report_reason lên NVARCHAR(255) nếu bảng đã tồn tại với kích thước nhỏ hơn
        IF EXISTS (
            SELECT 1 FROM sys.columns 
            WHERE object_id = OBJECT_ID('dbo.Review_Reports') 
              AND name = 'report_reason' 
              AND max_length < 510
        )
        BEGIN
            ALTER TABLE dbo.Review_Reports ALTER COLUMN report_reason NVARCHAR(255) NOT NULL;
            PRINT N'-> Đã mở rộng cột report_reason lên NVARCHAR(255).';
        END
    END

    IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Notifications')
    BEGIN
        CREATE TABLE Notifications (
            notification_id INT IDENTITY(1,1) PRIMARY KEY,
            user_id INT NOT NULL,
            title NVARCHAR(150) NOT NULL,
            message NVARCHAR(500) NOT NULL,
            type VARCHAR(30) NOT NULL DEFAULT 'SYSTEM',
            target_url VARCHAR(255) NULL,
            is_read BIT NOT NULL DEFAULT 0,
            created_at DATETIME DEFAULT DATEADD(HOUR, 7, GETUTCDATE()),

            CONSTRAINT FK_Notifications_Users FOREIGN KEY (user_id) REFERENCES dbo.Users(user_id) ON DELETE CASCADE
        );
        PRINT N'-> Đã tạo bảng Notifications thành công.';
    END

    -- -------------------------------------------------------------------------------
    -- 2. DI CHUYỂN DỮ LIỆU CŨ TỪ BẢNG REVIEWS SANG REVIEW_REPORTS (NẾU CÓ DỮ LIỆU CŨ)
    -- -------------------------------------------------------------------------------
    IF COL_LENGTH('dbo.Reviews', 'report_reason') IS NOT NULL
    BEGIN
        -- Lấy user_id đầu tiên làm đại diện cho các báo cáo cũ nếu chưa rõ người báo cáo
        DECLARE @default_admin_id INT;
        SELECT TOP 1 @default_admin_id = user_id FROM dbo.Users ORDER BY user_id ASC;

        IF @default_admin_id IS NOT NULL
        BEGIN
            INSERT INTO dbo.Review_Reports (review_id, user_id, report_reason, report_detail, reported_at)
            SELECT 
                r.review_id,
                @default_admin_id,
                LEFT(ISNULL(r.report_reason, N'Báo cáo cũ'), 255),
                N'Dữ liệu chuyển đổi hệ thống cũ',
                ISNULL(r.reported_at, DATEADD(HOUR, 7, GETUTCDATE()))
            FROM dbo.Reviews r
            WHERE (r.report_count > 0 OR r.report_status = 'PENDING')
              AND NOT EXISTS (
                  SELECT 1 FROM dbo.Review_Reports rr 
                  WHERE rr.review_id = r.review_id AND rr.user_id = @default_admin_id
              );
            
            PRINT N'-> Đã sao lưu dữ liệu báo cáo cũ sang Review_Reports an toàn.';
        END
    END

    -- -------------------------------------------------------------------------------
    -- 3. CẬP NHẬT CÁC STORED PROCEDURES (KHÔNG PHỤ THUỘC VÀO CÁC CỘT CŨ NỮA)
    -- -------------------------------------------------------------------------------

    -- 3.1. Procedure lấy danh sách vi phạm cho Admin (Tính count, gom reason từ bảng con)
    EXEC('
    CREATE OR ALTER PROCEDURE sp_GetReportedReviews
        @status VARCHAR(20) = NULL,
        @time_range VARCHAR(20) = ''all'',
        @search NVARCHAR(100) = NULL
    AS
    BEGIN
        SET NOCOUNT ON;

        SELECT 
            r.review_id,
            u.user_name AS violator_name,
            r.comment,
            r.rating,
            COUNT(rr.report_id) AS report_count,
            ISNULL(MIN(rr.report_reason), N''Không có'') AS report_reason,
            MAX(rr.reported_at) AS reported_at,
            r.report_status,
            g.name AS game_name
        FROM dbo.Reviews r
        JOIN dbo.Users u ON r.user_id = u.user_id
        JOIN dbo.Games g ON r.game_id = g.game_id
        LEFT JOIN dbo.Review_Reports rr ON r.review_id = rr.review_id
        WHERE r.report_status IN (''PENDING'', ''DISMISSED'', ''HIDDEN'')
          AND (@status IS NULL OR @status = ''ALL'' OR r.report_status = @status)
          AND (
              @time_range = ''all'' OR @time_range IS NULL
              OR (@time_range = ''today'' AND CAST(rr.reported_at AS DATE) = CAST(DATEADD(HOUR, 7, GETUTCDATE()) AS DATE))
              OR (@time_range = ''week''  AND rr.reported_at >= DATEADD(DAY, -7, DATEADD(HOUR, 7, GETUTCDATE())))
              OR (@time_range = ''month'' AND rr.reported_at >= DATEADD(MONTH, -1, DATEADD(HOUR, 7, GETUTCDATE())))
          )
          AND (
              @search IS NULL OR LTRIM(RTRIM(@search)) = ''''
              OR u.user_name LIKE N''%'' + LTRIM(RTRIM(@search)) + N''%''
              OR g.name LIKE N''%'' + LTRIM(RTRIM(@search)) + N''%''
              OR r.comment LIKE N''%'' + LTRIM(RTRIM(@search)) + N''%''
              OR rr.report_reason LIKE N''%'' + LTRIM(RTRIM(@search)) + N''%''
          )
        GROUP BY 
            r.review_id,
            u.user_name,
            r.comment,
            r.rating,
            r.report_status,
            g.name
        HAVING COUNT(rr.report_id) > 0 OR r.report_status IN (''DISMISSED'', ''HIDDEN'')
        ORDER BY 
            CASE WHEN r.report_status = ''PENDING'' THEN 0 ELSE 1 END,
            COUNT(rr.report_id) DESC,
            MAX(rr.reported_at) DESC;
    END;
    ');

    -- 3.2. Procedure báo cáo đánh giá (Chống spam, lưu bảng con, chỉ đổi status trên bảng Reviews)
    EXEC('
    CREATE OR ALTER PROCEDURE sp_ReportReview
        @review_id INT,
        @user_id INT,
        @report_reason NVARCHAR(100),
        @report_detail NVARCHAR(500) = NULL
    AS
    BEGIN
        SET NOCOUNT ON;

        IF NOT EXISTS (SELECT 1 FROM dbo.Reviews WHERE review_id = @review_id)
        BEGIN
            RAISERROR(N''Đánh giá không tồn tại'', 16, 1);
            RETURN;
        END

        IF EXISTS (SELECT 1 FROM dbo.Reviews WHERE review_id = @review_id AND user_id = @user_id)
        BEGIN
            RAISERROR(N''Bạn không thể tự báo cáo đánh giá của chính mình.'', 16, 1);
            RETURN;
        END

        IF EXISTS (SELECT 1 FROM dbo.Review_Reports WHERE review_id = @review_id AND user_id = @user_id)
        BEGIN
            RAISERROR(N''Bạn đã gửi báo cáo cho đánh giá này, vui lòng chờ quản trị viên xử lý.'', 16, 1);
            RETURN;
        END

        INSERT INTO dbo.Review_Reports (review_id, user_id, report_reason, report_detail, reported_at)
        VALUES (@review_id, @user_id, @report_reason, @report_detail, DATEADD(HOUR, 7, GETUTCDATE()));

        UPDATE dbo.Reviews
        SET report_status = ''PENDING''
        WHERE review_id = @review_id;
    END;
    ');

    -- 3.3. Procedure lấy danh sách chi tiết người báo cáo của 1 review (cho popup Admin)
    EXEC('
    CREATE OR ALTER PROCEDURE sp_GetReviewReportDetails
        @review_id INT
    AS
    BEGIN
        SET NOCOUNT ON;

        SELECT 
            rr.report_id,
            rr.review_id,
            rr.user_id,
            u.user_name AS reporter_name,
            rr.report_reason,
            rr.report_detail,
            rr.reported_at
        FROM dbo.Review_Reports rr
        JOIN dbo.Users u ON rr.user_id = u.user_id
        WHERE rr.review_id = @review_id
        ORDER BY rr.reported_at DESC;
    END;
    ');

    -- 3.4. Procedure duyệt báo cáo (Ẩn/Bỏ qua + Tự động gửi Notifications)
    EXEC('
    CREATE OR ALTER PROCEDURE sp_ModerateReview
        @review_id INT,
        @action VARCHAR(20) -- ''HIDE'' hoặc ''DISMISS''
    AS
    BEGIN
        SET NOCOUNT ON;

        IF NOT EXISTS (SELECT 1 FROM dbo.Reviews WHERE review_id = @review_id)
        BEGIN
            RAISERROR(N''Đánh giá không tồn tại'', 16, 1);
            RETURN;
        END

        DECLARE @violator_id INT;
        DECLARE @game_id INT;
        DECLARE @game_name NVARCHAR(255);

        SELECT 
            @violator_id = r.user_id,
            @game_id = r.game_id,
            @game_name = g.name
        FROM dbo.Reviews r
        JOIN dbo.Games g ON r.game_id = g.game_id
        WHERE r.review_id = @review_id;

        IF @action = ''HIDE''
        BEGIN
            UPDATE dbo.Reviews
            SET 
                is_hidden = 1,
                report_status = ''HIDDEN''
            WHERE review_id = @review_id;

            -- 1. Thông báo cho người bị ẩn bình luận
            INSERT INTO dbo.Notifications (user_id, title, message, type, target_url, is_read, created_at)
            VALUES (
                @violator_id,
                N''Bình luận của bạn đã bị ẩn'',
                N''Bình luận của bạn tại tựa game "'' + ISNULL(@game_name, N'''') + N''" đã bị Ban quản trị ẩn do vi phạm tiêu chuẩn cộng đồng.'',
                ''REVIEW_HIDDEN'',
                ''html/game-details.html?id='' + CAST(@game_id AS VARCHAR(10)) + ''#review-'' + CAST(@review_id AS VARCHAR(10)),
                0,
                DATEADD(HOUR, 7, GETUTCDATE())
            );

            -- 2. Thông báo cảm ơn cho tất cả những người đã gửi báo cáo bình luận này
            INSERT INTO dbo.Notifications (user_id, title, message, type, target_url, is_read, created_at)
            SELECT 
                rr.user_id,
                N''Báo cáo của bạn đã được xử lý'',
                N''Cảm ơn bạn đã phản ánh. Bình luận vi phạm tại tựa game "'' + ISNULL(@game_name, N'''') + N''" mà bạn báo cáo đã được các quản trị viên xử lý.'',
                ''REPORT_RESULT'',
                ''/html/game-details.html?id='' + CAST(@game_id AS VARCHAR(10)),
                0,
                DATEADD(HOUR, 7, GETUTCDATE())
            FROM dbo.Review_Reports rr
            WHERE rr.review_id = @review_id;
        END
        ELSE IF @action = ''DISMISS''
        BEGIN
            UPDATE dbo.Reviews
            SET 
                is_hidden = 0,
                report_status = ''DISMISSED''
            WHERE review_id = @review_id;
        END
        ELSE
        BEGIN
            RAISERROR(N''Hành động không hợp lệ (chỉ chấp nhận HIDE hoặc DISMISS)'', 16, 1);
            RETURN;
        END
    END;
    ');

    -- 3.5. Các Procedure lấy & cập nhật thông báo (Notifications)
    EXEC('
    CREATE OR ALTER PROCEDURE sp_GetUserNotifications
        @user_id INT,
        @limit INT = 20
    AS
    BEGIN
        SET NOCOUNT ON;
        SELECT TOP (@limit)
            notification_id, user_id, title, message, type, target_url, is_read, created_at
        FROM dbo.Notifications
        WHERE user_id = @user_id
        ORDER BY created_at DESC;
    END;
    ');

    EXEC('
    CREATE OR ALTER PROCEDURE sp_GetUnreadNotificationCount
        @user_id INT
    AS
    BEGIN
        SET NOCOUNT ON;
        SELECT COUNT(*) AS unread_count
        FROM dbo.Notifications
        WHERE user_id = @user_id AND is_read = 0;
    END;
    ');

    EXEC('
    CREATE OR ALTER PROCEDURE sp_MarkNotificationAsRead
        @user_id INT,
        @notification_id INT = NULL
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
    ');

    -- -------------------------------------------------------------------------------
    -- 4. XÓA AN TOÀN CÁC RÀNG BUỘC VÀ CỘT THỪA TRÊN BẢNG REVIEWS
    -- -------------------------------------------------------------------------------
    
    -- Xóa Check constraint report_count nếu tồn tại
    IF EXISTS (SELECT * FROM sys.check_constraints WHERE name = 'CK_Reviews_ReportCount')
    BEGIN
        ALTER TABLE dbo.Reviews DROP CONSTRAINT CK_Reviews_ReportCount;
        PRINT N'-> Đã gỡ Check constraint CK_Reviews_ReportCount.';
    END

    -- Gỡ tất cả Default Constraints gắn với report_count, report_reason, reported_at
    DECLARE @sqlDropDefaults NVARCHAR(MAX) = N'';
    SELECT @sqlDropDefaults += N'ALTER TABLE dbo.Reviews DROP CONSTRAINT ' + dc.name + N'; '
    FROM sys.default_constraints dc
    JOIN sys.columns c ON dc.parent_object_id = c.object_id AND dc.parent_column_id = c.column_id
    WHERE dc.parent_object_id = OBJECT_ID('dbo.Reviews')
      AND c.name IN ('report_count', 'report_reason', 'reported_at');

    IF LEN(@sqlDropDefaults) > 0
    BEGIN
        EXEC sp_executesql @sqlDropDefaults;
        PRINT N'-> Đã gỡ Default Constraints trên các cột cũ.';
    END

    -- Gỡ Indexes nếu có trên 3 cột này (đề phòng)
    DECLARE @sqlDropIndexes NVARCHAR(MAX) = N'';
    SELECT @sqlDropIndexes += N'DROP INDEX ' + i.name + N' ON dbo.Reviews; '
    FROM sys.indexes i
    JOIN sys.index_columns ic ON i.object_id = ic.object_id AND i.index_id = ic.index_id
    JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
    WHERE i.object_id = OBJECT_ID('dbo.Reviews')
      AND i.is_primary_key = 0 AND i.is_unique_constraint = 0
      AND c.name IN ('report_count', 'report_reason', 'reported_at');

    IF LEN(@sqlDropIndexes) > 0
    BEGIN
        EXEC sp_executesql @sqlDropIndexes;
        PRINT N'-> Đã gỡ Indexes liên quan đến các cột cũ.';
    END

    -- Xóa 3 cột thừa
    IF COL_LENGTH('dbo.Reviews', 'report_reason') IS NOT NULL
    BEGIN
        ALTER TABLE dbo.Reviews DROP COLUMN report_reason;
        PRINT N'-> Đã xóa cột report_reason khỏi bảng Reviews.';
    END

    IF COL_LENGTH('dbo.Reviews', 'report_count') IS NOT NULL
    BEGIN
        ALTER TABLE dbo.Reviews DROP COLUMN report_count;
        PRINT N'-> Đã xóa cột report_count khỏi bảng Reviews.';
    END

    IF COL_LENGTH('dbo.Reviews', 'reported_at') IS NOT NULL
    BEGIN
        ALTER TABLE dbo.Reviews DROP COLUMN reported_at;
        PRINT N'-> Đã xóa cột reported_at khỏi bảng Reviews.';
    END

    COMMIT TRANSACTION;
    PRINT N'==========================================================';
    PRINT N'THÀNH CÔNG: CSDL ĐÃ ĐƯỢC CHUẨN HÓA AN TOÀN VÀ HOÀN TẤT!';
    PRINT N'==========================================================';

END TRY
BEGIN CATCH
    ROLLBACK TRANSACTION;
    PRINT N'LỖI: ' + ERROR_MESSAGE();
    THROW;
END CATCH;
GO
