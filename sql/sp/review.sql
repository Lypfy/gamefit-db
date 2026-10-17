-- Viết đánh gía 
CREATE OR ALTER PROCEDURE sp_WriteReview
    @user_id INT,
    @game_id INT,
    @rating INT,
    @comment NVARCHAR(MAX)
AS
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM vw_Game_Detail
        WHERE game_id = @game_id
    )
    BEGIN
        RAISERROR(N'Game không tồn tại trong hệ thống', 16, 1)
        RETURN
    END

    IF NOT EXISTS (
        SELECT 1 
        FROM vw_User_Safe_Profile
        WHERE user_id = @user_id
    )
    BEGIN
        RAISERROR(N'Người dùng không tồn tại trong hệ thống', 16, 1)
        RETURN 
    END

    IF (@rating < 1 OR @rating > 5)
    BEGIN
        RAISERROR(N'Điểm đánh giá không được bé hơn 1 và không được lớn hơn 5', 16, 1)
        RETURN
    END

    IF EXISTS (
        SELECT 1
        FROM Reviews
        WHERE user_id = @user_id AND game_id = @game_id
    )
    BEGIN
        RAISERROR(N'Bạn đã viết đánh giá game này rồi', 16, 1)
        RETURN 
    END

    INSERT INTO Reviews(user_id, game_id, rating, comment)
    VALUES(@user_id, @game_id, @rating, @comment)
END 
GO 

-- Cập nhật đánh giá 
CREATE OR ALTER PROCEDURE sp_UpdateReview(@user_id INT, @game_id INT, @rating INT, @comment NVARCHAR(MAX)) 
AS
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM vw_Game_Detail
        WHERE game_id = @game_id
    )
    BEGIN
        RAISERROR(N'Game không tồn tại trong hệ thống', 16, 1)
        RETURN
    END

    IF NOT EXISTS (
        SELECT 1 
        FROM vw_User_Safe_Profile
        WHERE user_id = @user_id
    )
    BEGIN
        RAISERROR(N'Người dùng không tồn tại trong hệ thống', 16, 1)
        RETURN 
    END

    IF (@rating < 1 OR @rating > 5)
    BEGIN
        RAISERROR(N'Điểm đánh giá không được bé hơn 1 và không được lớn hơn 5', 16, 1)
        RETURN
    END

    IF NOT EXISTS (
        SELECT 1 
        FROM Reviews 
        WHERE user_id = @user_id AND game_id = @game_id
    )
    BEGIN
        RAISERROR(N'Bạn chưa có đánh giá nào cho game này để cập nhật', 16, 1)
        RETURN 
    END

    UPDATE Reviews
    SET rating = @rating, comment = @comment
    WHERE user_id = @user_id AND game_id = @game_id
END
GO 

-- Xóa Đánh giá (Transaction dọn sạch Votes và Reports tránh dữ liệu mồ côi)
CREATE OR ALTER PROCEDURE sp_DeleteReview
    @user_id INT,
    @game_id INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @review_id INT;
    SELECT @review_id = review_id 
    FROM Reviews 
    WHERE user_id = @user_id AND game_id = @game_id;

    IF @review_id IS NOT NULL
    BEGIN
        BEGIN TRY
            BEGIN TRANSACTION;

            -- 1. Xóa các lượt Vote của Review này (bảng Votes đa hình không có FK cascade)
            IF EXISTS (SELECT 1 FROM sys.tables WHERE name = 'Votes')
            BEGIN
                DELETE FROM Votes 
                WHERE target_type = 'REVIEW' AND target_id = @review_id;
            END;

            -- 2. Xóa các Báo cáo vi phạm của Review này
            IF EXISTS (SELECT 1 FROM sys.tables WHERE name = 'Review_Reports')
            BEGIN
                DELETE FROM Review_Reports 
                WHERE review_id = @review_id;
            END;

            -- 3. Xóa chính bản ghi Review
            DELETE FROM Reviews 
            WHERE review_id = @review_id;

            COMMIT TRANSACTION;
        END TRY
        BEGIN CATCH
            IF @@TRANCOUNT > 0
                ROLLBACK TRANSACTION;
            DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE();
            RAISERROR(@ErrMsg, 16, 1);
        END CATCH;
    END;
END;
GO

CREATE OR ALTER PROCEDURE sp_GetReportedReviews
    @status VARCHAR(20) = NULL,       -- 'PENDING', 'DISMISSED', 'HIDDEN' hoặc NULL / 'ALL' (lấy tất cả)
    @time_range VARCHAR(20) = 'all',  -- 'all', 'today', 'week', 'month'
    @search NVARCHAR(100) = NULL      -- Tìm theo tên người vi phạm, tên game, lý do báo cáo
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        r.review_id,
        u.user_name AS violator_name,
        r.comment,
        r.rating,
        COUNT(rr.report_id) AS report_count,
        ISNULL(MIN(rr.report_reason), N'Không có') AS report_reason,
        MAX(rr.reported_at) AS reported_at,
        r.report_status,
        g.name AS game_name
    FROM dbo.Reviews r
    JOIN dbo.Users u ON r.user_id = u.user_id
    JOIN dbo.Games g ON r.game_id = g.game_id
    LEFT JOIN dbo.Review_Reports rr ON r.review_id = rr.review_id
    WHERE r.report_status IN ('PENDING', 'DISMISSED', 'HIDDEN')
      AND (@status IS NULL OR @status = 'ALL' OR r.report_status = @status)
      AND (
          @time_range = 'all' OR @time_range IS NULL
          OR (@time_range = 'today' AND CAST(rr.reported_at AS DATE) = CAST(DATEADD(HOUR, 7, GETUTCDATE()) AS DATE))
          OR (@time_range = 'week'  AND rr.reported_at >= DATEADD(DAY, -7, DATEADD(HOUR, 7, GETUTCDATE())))
          OR (@time_range = 'month' AND rr.reported_at >= DATEADD(MONTH, -1, DATEADD(HOUR, 7, GETUTCDATE())))
      )
      AND (
          @search IS NULL OR LTRIM(RTRIM(@search)) = ''
          OR u.user_name LIKE N'%' + LTRIM(RTRIM(@search)) + N'%'
          OR g.name LIKE N'%' + LTRIM(RTRIM(@search)) + N'%'
          OR r.comment LIKE N'%' + LTRIM(RTRIM(@search)) + N'%'
          OR rr.report_reason LIKE N'%' + LTRIM(RTRIM(@search)) + N'%'
      )
    GROUP BY 
        r.review_id,
        u.user_name,
        r.comment,
        r.rating,
        r.report_status,
        g.name
    HAVING COUNT(rr.report_id) > 0 OR r.report_status IN ('DISMISSED', 'HIDDEN')
    ORDER BY 
        CASE WHEN r.report_status = 'PENDING' THEN 0 ELSE 1 END,
        COUNT(rr.report_id) DESC,
        MAX(rr.reported_at) DESC;
END;
GO

-- Báo cáo đánh giá vi phạm (Lưu vào bảng Review_Reports, chống spam, không lưu chuỗi trên Reviews)
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
        RAISERROR(N'Đánh giá không tồn tại', 16, 1);
        RETURN;
    END

    -- Ngăn không cho tự báo cáo đánh giá của chính mình
    IF EXISTS (SELECT 1 FROM dbo.Reviews WHERE review_id = @review_id AND user_id = @user_id)
    BEGIN
        RAISERROR(N'Bạn không thể tự báo cáo đánh giá của chính mình.', 16, 1);
        RETURN;
    END

    -- Kiểm tra người dùng đã báo cáo đánh giá này chưa (chống spam)
    IF EXISTS (SELECT 1 FROM dbo.Review_Reports WHERE review_id = @review_id AND user_id = @user_id)
    BEGIN
        RAISERROR(N'Bạn đã gửi báo cáo cho đánh giá này rồi, vui lòng chờ quản trị viên xử lý.', 16, 1);
        RETURN;
    END

    INSERT INTO dbo.Review_Reports (review_id, user_id, report_reason, report_detail, reported_at)
    VALUES (@review_id, @user_id, @report_reason, @report_detail, DATEADD(HOUR, 7, GETUTCDATE()));

    -- Cập nhật bảng Reviews (chuyển sang PENDING để Admin duyệt)
    UPDATE dbo.Reviews
    SET report_status = 'PENDING'
    WHERE review_id = @review_id;
END;
GO

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
GO

CREATE OR ALTER PROCEDURE sp_ModerateReview
    @review_id INT,
    @action VARCHAR(20) -- 'HIDE' (Ẩn đánh giá) hoặc 'DISMISS' (Bỏ qua báo cáo)
AS
BEGIN
    SET NOCOUNT ON;

    -- 1. Kiểm tra sự tồn tại của Review
    IF NOT EXISTS (SELECT 1 FROM dbo.Reviews WHERE review_id = @review_id)
    BEGIN
        RAISERROR(N'Đánh giá không tồn tại', 16, 1);
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

    IF @action = 'HIDE'
    BEGIN
        -- Xác nhận vi phạm: Ẩn đánh giá khỏi người dùng và cập nhật trạng thái
        UPDATE dbo.Reviews
        SET 
            is_hidden = 1,
            report_status = 'HIDDEN'
        WHERE review_id = @review_id;

        -- TỰ ĐỘNG GỬI NOTIFICATION:
        -- 1. Thông báo cho người vi phạm (tác giả bình luận)
        IF EXISTS (SELECT * FROM sys.tables WHERE name = 'Notifications')
        BEGIN
            INSERT INTO dbo.Notifications (user_id, title, message, type, target_url, is_read, created_at)
            VALUES (
                @violator_id,
                N'Bình luận của bạn đã bị ẩn',
                N'Bình luận của bạn tại tựa game "' + @game_name + N'" đã bị Ban quản trị ẩn do vi phạm tiêu chuẩn cộng đồng.',
                'REVIEW_HIDDEN',
                '/html/game-details.html?id=' + CAST(@game_id AS VARCHAR(10)) + '#review-' + CAST(@review_id AS VARCHAR(10)) + '#review-' + CAST(@review_id AS VARCHAR(10)),
                0,
                DATEADD(HOUR, 7, GETUTCDATE())
            );

            -- 2. Thông báo cảm ơn cho tất cả những người đã gửi báo cáo bình luận này
            IF EXISTS (SELECT * FROM sys.tables WHERE name = 'Review_Reports')
            BEGIN
                INSERT INTO dbo.Notifications (user_id, title, message, type, target_url, is_read, created_at)
                SELECT 
                    rr.user_id,
                    N'Báo cáo của bạn đã được xử lý',
                    N'Cảm ơn bạn đã phản ánh. Bình luận vi phạm tại tựa game "' + @game_name + N'" mà bạn báo cáo đã được Ban quản trị xử lý.',
                    'REPORT_RESULT',
                    '/html/game-details.html?id=' + CAST(@game_id AS VARCHAR(10)),
                    0,
                    DATEADD(HOUR, 7, GETUTCDATE())
                FROM dbo.Review_Reports rr
                WHERE rr.review_id = @review_id;
            END
        END
    END
    ELSE IF @action = 'DISMISS'
    BEGIN
        -- Báo cáo sai / không vi phạm: Mở lại hiển thị bình luận và chuyển sang trạng thái Đã bỏ qua
        UPDATE dbo.Reviews
        SET 
            is_hidden = 0,
            report_status = 'DISMISSED'
        WHERE review_id = @review_id;
    END
    ELSE
    BEGIN
        RAISERROR(N'Hành động không hợp lệ (chỉ chấp nhận HIDE hoặc DISMISS)', 16, 1);
        RETURN;
    END
END;
GO




