-- Đề xuất 
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

-- Lấy danh sách
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
        gpr.created_at

    FROM Game_PC_Recommendation gpr

    JOIN Users u
        ON gpr.user_id = u.user_id

    JOIN vw_User_PC_Detail v
        ON gpr.pc_id = v.pc_id

    WHERE gpr.game_id = @game_id
        AND gpr.is_hidden = 0

    ORDER BY gpr.created_at DESC;
END;

-- Xóa 
CREATE OR ALTER PROCEDURE sp_DeleteGamePCRecommendation
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

-- Vote 
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

