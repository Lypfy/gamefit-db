-- ===================================================================================
-- STORED PROCEDURES: GAME PC RECOMMENDATION (ĐỀ XUẤT CẤU HÌNH & QUẢN TRỊ ADMIN)
-- Dự án: GameFit
-- ===================================================================================

-- 1. Đề xuất cấu hình mới
CREATE OR ALTER PROCEDURE sp_CreateGamePCRecommendation
    @user_id INT,
    @game_id INT,
    @pc_id INT,
    @type VARCHAR(20),
    @note NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO Game_PC_Recommendation
    (
        user_id,
        game_id,
        pc_id,
        type,
        note
    )
    VALUES
    (
        @user_id,
        @game_id,
        @pc_id,
        @type,
        @note
    );
END;
GO

-- 2. Lấy danh sách đề xuất cấu hình hiển thị phía người dùng (Trang chi tiết Game)
CREATE OR ALTER PROCEDURE sp_GetGamePCRecommendations
    @game_id INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        gpr.recommendation_id,
        gpr.user_id,
        u.user_name,
        gpr.game_id,
        gpr.pc_id,
        v.pc_name,

        v.user_os AS os,
        v.user_ram AS ram,
        v.user_storage AS storage,
        v.cpu_name,
        v.gpu_name,

        gpr.type,
        gpr.note,
        gpr.status,
        gpr.created_at

    FROM Game_PC_Recommendation gpr
    JOIN Users u ON gpr.user_id = u.user_id
    JOIN vw_User_PC_Detail v ON gpr.pc_id = v.pc_id

    WHERE gpr.game_id = @game_id
      AND gpr.is_hidden = 0
      AND ISNULL(gpr.status, 'PENDING') <> 'REJECTED' -- Ẩn các đề xuất bị từ chối

    ORDER BY gpr.created_at DESC;
END;
GO

-- 3. Xóa mềm (Ẩn đề xuất của chính người dùng)
CREATE OR ALTER PROCEDURE sp_HideGamePCRecommendation
    @user_id INT,
    @recommendation_id INT
AS
BEGIN
    SET NOCOUNT ON;
    DELETE FROM Game_PC_Recommendation
    WHERE recommendation_id = @recommendation_id
      AND user_id = @user_id;
END;
GO


-- 4. Vote đề xuất hoặc đánh giá
CREATE OR ALTER PROCEDURE sp_Vote
    @user_id INT,
    @target_type VARCHAR(20),
    @target_id INT,
    @vote_type SMALLINT
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1
        FROM Votes
        WHERE user_id = @user_id
          AND target_type = @target_type
          AND target_id = @target_id
    )
    BEGIN
        IF (
            SELECT vote_type
            FROM Votes
            WHERE user_id = @user_id
              AND target_type = @target_type
              AND target_id = @target_id
        ) = @vote_type
        BEGIN
            -- Bấm lại nút cũ -> bỏ vote
            DELETE FROM Votes
            WHERE user_id = @user_id
              AND target_type = @target_type
              AND target_id = @target_id;
        END
        ELSE
        BEGIN
            -- Đổi Like <-> Dislike
            UPDATE Votes
            SET vote_type = @vote_type
            WHERE user_id = @user_id
              AND target_type = @target_type
              AND target_id = @target_id;
        END
    END
    ELSE
    BEGIN
        -- Chưa vote -> thêm mới
        INSERT INTO Votes(user_id, target_type, target_id, vote_type)
        VALUES (@user_id, @target_type, @target_id, @vote_type);
    END
END;
GO

-- ===================================================================================
-- CÁC THỦ TỤC DÀNH CHO ADMIN QUẢN TRỊ ĐỀ XUẤT CẤU HÌNH
-- ===================================================================================

-- 5. Lấy danh sách đề xuất cấu hình cho Admin Dashboard
CREATE OR ALTER PROCEDURE sp_Admin_GetGamePCRecommendations
    @status VARCHAR(20) = NULL,
    @type VARCHAR(20) = NULL,
    @search NVARCHAR(100) = NULL,
    @min_votes INT = 1 -- Số điểm vote thực tế tối thiểu (upvote - downvote), mặc định = 1 (chỉ lấy điểm dương > 0)
AS
BEGIN
    SET NOCOUNT ON;

    -- Mặc định lọc các đề xuất có điểm thực tế >= 1 nếu truyền NULL
    SET @min_votes = ISNULL(@min_votes, 1);

    SELECT 
        gpr.recommendation_id,
        gpr.game_id,
        g.name AS game_name,
        g.image AS game_image,
        gpr.user_id,
        u.user_name AS reporter_name,
        gpr.pc_id,
        v.pc_name,
        v.cpu_name,
        v.user_cpu_benchmark AS cpu_benchmark,
        v.gpu_name,
        v.user_gpu_benchmark AS gpu_benchmark,
        v.user_ram AS ram,
        v.user_storage AS storage,
        v.user_os AS os,
        gpr.type,
        gpr.note,
        gpr.status,
        gpr.created_at,
        gpr.reviewed_at,
        gpr.reviewed_by,
        admin_u.user_name AS reviewer_name,
        gpr.reject_reason,

        -- Tính điểm Vote: Net Score = Upvote - Downvote
        ISNULL(vt.net_votes, 0) AS net_votes,
        ISNULL(vt.upvotes, 0) AS upvotes,
        ISNULL(vt.downvotes, 0) AS downvotes

    FROM Game_PC_Recommendation gpr
    JOIN Games g ON gpr.game_id = g.game_id
    JOIN Users u ON gpr.user_id = u.user_id
    JOIN vw_User_PC_Detail v ON gpr.pc_id = v.pc_id
    LEFT JOIN Users admin_u ON gpr.reviewed_by = admin_u.user_id
    JOIN (
        SELECT 
            target_id,
            SUM(vote_type) AS net_votes,
            SUM(CASE WHEN vote_type = 1 THEN 1 ELSE 0 END) AS upvotes,
            SUM(CASE WHEN vote_type = -1 THEN 1 ELSE 0 END) AS downvotes
        FROM Votes
        WHERE target_type = 'RECOMMENDATION'
        GROUP BY target_id
    ) vt ON gpr.recommendation_id = vt.target_id

    WHERE gpr.is_hidden = 0
      AND (@status IS NULL OR @status = '' OR gpr.status = @status)
      AND (@type IS NULL OR @type = '' OR gpr.type = @type)
      AND (
            @search IS NULL OR @search = ''
            OR g.name LIKE N'%' + @search + N'%'
            OR u.user_name LIKE N'%' + @search + N'%'
            OR v.pc_name LIKE N'%' + @search + N'%'
      )
      -- Lọc theo số điểm vote thực tế (net_votes = upvotes - downvotes)
      AND vt.net_votes >= @min_votes
    ORDER BY 
        CASE WHEN gpr.status = 'PENDING' THEN 0 ELSE 1 END ASC,
        ISNULL(vt.net_votes, 0) DESC,
        gpr.created_at DESC;
END;
GO

-- 6. Lấy chi tiết đề xuất kèm thông số so sánh với cấu hình hiện tại của Game
CREATE OR ALTER PROCEDURE sp_Admin_GetRecommendationDetail
    @recommendation_id INT
AS
BEGIN
    SET NOCOUNT ON;

    -- Kết quả 1: Chi tiết đề xuất của User
    SELECT 
        gpr.recommendation_id,
        gpr.game_id,
        g.name AS game_name,
        g.image AS game_image,
        gpr.user_id,
        u.user_name,
        gpr.pc_id,
        v.pc_name,
        v.cpu_name,
        v.user_cpu_benchmark AS cpu_benchmark,
        v.gpu_name,
        v.user_gpu_benchmark AS gpu_benchmark,
        v.user_ram AS ram,
        v.user_storage AS storage,
        v.user_os AS os,
        gpr.type,
        gpr.note,
        gpr.status,
        gpr.created_at,
        gpr.reviewed_at,
        gpr.reviewed_by,
        admin_u.user_name AS reviewer_name,
        gpr.reject_reason,
        ISNULL(vt.net_votes, 0) AS net_votes,
        ISNULL(vt.upvotes, 0) AS upvotes,
        ISNULL(vt.downvotes, 0) AS downvotes
    FROM Game_PC_Recommendation gpr
    JOIN Games g ON gpr.game_id = g.game_id
    JOIN Users u ON gpr.user_id = u.user_id
    JOIN vw_User_PC_Detail v ON gpr.pc_id = v.pc_id
    LEFT JOIN Users admin_u ON gpr.reviewed_by = admin_u.user_id
    LEFT JOIN (
        SELECT 
            target_id,
            SUM(vote_type) AS net_votes,
            SUM(CASE WHEN vote_type = 1 THEN 1 ELSE 0 END) AS upvotes,
            SUM(CASE WHEN vote_type = -1 THEN 1 ELSE 0 END) AS downvotes
        FROM Votes
        WHERE target_type = 'RECOMMENDATION'
        GROUP BY target_id
    ) vt ON gpr.recommendation_id = vt.target_id
    WHERE gpr.recommendation_id = @recommendation_id;

    -- Kết quả 2: Cấu hình hiện tại của Game trong Game_requirement
    SELECT 
        grd.game_id,
        grd.game_name,
        grd.type,
        grd.cpu_name,
        grd.cpu_benchmark,
        grd.gpu_name,
        grd.gpu_benchmark,
        grd.ram,
        grd.storage,
        grd.os
    FROM vw_Game_Requirement_Detail grd
    WHERE grd.game_id = (SELECT game_id FROM Game_PC_Recommendation WHERE recommendation_id = @recommendation_id);
END;
GO

-- 7. Duyệt đề xuất & Apply vào Game_requirement với TRANSACTION an toàn
CREATE OR ALTER PROCEDURE sp_Admin_ApproveRecommendation
    @recommendation_id INT,
    @admin_id INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @game_id INT, @user_id INT, @pc_id INT, @type VARCHAR(20), @status VARCHAR(20);
    DECLARE @cpu_id INT, @gpu_id INT, @ram INT, @storage INT, @os VARCHAR(50);
    DECLARE @game_name NVARCHAR(255), @pc_name NVARCHAR(255);

    -- Lấy thông tin đề xuất
    SELECT 
        @game_id = gpr.game_id,
        @user_id = gpr.user_id,
        @pc_id = gpr.pc_id,
        @type = gpr.type,
        @status = gpr.status,
        @game_name = g.name,
        @pc_name = upc.pc_name,
        @cpu_id = upc.cpu_id,
        @gpu_id = upc.gpu_id,
        @ram = upc.ram,
        @storage = upc.storage,
        @os = upc.os
    FROM Game_PC_Recommendation gpr
    JOIN Games g ON gpr.game_id = g.game_id
    JOIN User_pc upc ON gpr.pc_id = upc.pc_id
    WHERE gpr.recommendation_id = @recommendation_id;

    IF @game_id IS NULL
    BEGIN
        RAISERROR(N'Đề xuất cấu hình không tồn tại.', 16, 1);
        RETURN;
    END

    IF @status = 'APPROVED'
    BEGIN
        RAISERROR(N'Đề xuất cấu hình này đã được duyệt trước đó rồi.', 16, 1);
        RETURN;
    END

    BEGIN TRANSACTION;
    BEGIN TRY
        -- 1. Chuyển đề xuất cũ đang là APPROVED (cùng game_id và cùng type) thành REPLACED
        UPDATE Game_PC_Recommendation
        SET status = 'REPLACED'
        WHERE game_id = @game_id
          AND type = @type
          AND status = 'APPROVED'
          AND recommendation_id <> @recommendation_id;

        -- 2. Cập nhật đề xuất hiện tại thành APPROVED
        UPDATE Game_PC_Recommendation
        SET 
            status = 'APPROVED',
            reviewed_by = @admin_id,
            reviewed_at = DATEADD(HOUR, 7, GETUTCDATE()),
            reject_reason = NULL
        WHERE recommendation_id = @recommendation_id;

        -- 3. Áp dụng vào bảng Game_requirement (Update nếu đã có, Insert nếu chưa có)
        IF EXISTS (
            SELECT 1 FROM dbo.Game_requirement 
            WHERE game_id = @game_id AND UPPER(type) = UPPER(@type)
        )
        BEGIN
            UPDATE dbo.Game_requirement
            SET 
                cpu_id = @cpu_id,
                gpu_id = @gpu_id,
                ram = @ram,
                storage = @storage,
                os = @os
            WHERE game_id = @game_id AND UPPER(type) = UPPER(@type);
        END
        ELSE
        BEGIN
            INSERT INTO dbo.Game_requirement (game_id, type, cpu_id, gpu_id, ram, storage, os)
            VALUES (@game_id, @type, @cpu_id, @gpu_id, @ram, @storage, @os);
        END

        -- 4. Tự động gửi thông báo chúc mừng đến người dùng (Notifications)
        IF EXISTS (SELECT 1 FROM sys.tables WHERE name = 'Notifications')
        BEGIN
            DECLARE @type_text NVARCHAR(50) = CASE WHEN @type = 'MINIMUM' THEN N'Tối thiểu' ELSE N'Khuyến nghị' END;
            DECLARE @msg NVARCHAR(500) = N'Chúc mừng! Cấu hình dàn máy "' + @pc_name + N'" của bạn đã được Ban quản trị duyệt và áp dụng làm cấu hình ' + @type_text + N' cho tựa game "' + @game_name + N'".';

            INSERT INTO dbo.Notifications (user_id, title, message, type, target_url, is_read, created_at)
            VALUES (
                @user_id,
                N'Đề xuất cấu hình được chấp thuận',
                @msg,
                'SYSTEM',
                '/html/game-details.html?id=' + CAST(@game_id AS VARCHAR(10)),
                0,
                DATEADD(HOUR, 7, GETUTCDATE())
            );
        END

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE();
        -- Bắt lỗi trigger xung đột Min > Rec
        IF @ErrMsg LIKE N'%Cấu hình Khuyến nghị (RECOMMENDED) không thể yếu hơn%' OR @ErrMsg LIKE N'%trg_GameRequirement_Check%'
        BEGIN
            RAISERROR(N'Xung đột cấu hình: Cấu hình Khuyến nghị không được phép yếu hơn cấu hình Tối thiểu.', 16, 1);
        END
        ELSE
        BEGIN
            RAISERROR(@ErrMsg, 16, 1);
        END
    END CATCH
END;
GO

-- 8. Từ chối đề xuất + gửi Notification kèm lý do
CREATE OR ALTER PROCEDURE sp_Admin_RejectRecommendation
    @recommendation_id INT,
    @admin_id INT,
    @reject_reason NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @game_id INT, @user_id INT, @game_name NVARCHAR(255);

    SELECT 
        @game_id = gpr.game_id,
        @user_id = gpr.user_id,
        @game_name = g.name
    FROM Game_PC_Recommendation gpr
    JOIN Games g ON gpr.game_id = g.game_id
    WHERE gpr.recommendation_id = @recommendation_id;

    IF @game_id IS NULL
    BEGIN
        RAISERROR(N'Đề xuất cấu hình không tồn tại.', 16, 1);
        RETURN;
    END

    BEGIN TRANSACTION;
    BEGIN TRY
        UPDATE Game_PC_Recommendation
        SET 
            status = 'REJECTED',
            reviewed_by = @admin_id,
            reviewed_at = DATEADD(HOUR, 7, GETUTCDATE()),
            reject_reason = @reject_reason
        WHERE recommendation_id = @recommendation_id;

        -- Gửi thông báo từ chối cho người đề xuất
        IF EXISTS (SELECT 1 FROM sys.tables WHERE name = 'Notifications')
        BEGIN
            DECLARE @msg NVARCHAR(500) = N'Đề xuất cấu hình của bạn cho tựa game "' + @game_name + N'" đã không được duyệt.';
            IF @reject_reason IS NOT NULL AND LEN(LTRIM(RTRIM(@reject_reason))) > 0
            BEGIN
                SET @msg = @msg + N' Lý do: ' + @reject_reason;
            END

            INSERT INTO dbo.Notifications (user_id, title, message, type, target_url, is_read, created_at)
            VALUES (
                @user_id,
                N'Đề xuất cấu hình không được duyệt',
                @msg,
                'SYSTEM',
                '/html/game-details.html?id=' + CAST(@game_id AS VARCHAR(10)),
                0,
                DATEADD(HOUR, 7, GETUTCDATE())
            );
        END

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@ErrMsg, 16, 1);
    END CATCH
END;
GO
