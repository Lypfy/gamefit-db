CREATE OR ALTER PROCEDURE sp_addGame(
    @name NVARCHAR(255), 
    @description NVARCHAR(MAX), 
    @publisher NVARCHAR(255), 
    @developer NVARCHAR(255), 
    @name_tag NVARCHAR(MAX),  
    @release_date DATETIME, 
    @download_url VARCHAR(500),
    @image NVARCHAR(MAX) = NULL -- Bổ sung tham số nhận chuỗi URL ảnh
) 
AS
BEGIN  
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @game_id INT;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- 1. Thêm game vào bảng Games (Bao gồm cả cột image)
        INSERT INTO Games(name, description, publisher, developer, release_date, download_url, image) 
        VALUES (@name, @description, @publisher, @developer, @release_date, @download_url, @image);

        -- 2. Lấy ID game vừa tạo
        SET @game_id = SCOPE_IDENTITY();

        -- 3. Gán các tag cho game (Đảm bảo nếu tag thêm lỗi thì toàn bộ việc thêm game được rollback)
        IF @name_tag IS NOT NULL AND LEN(TRIM(@name_tag)) > 0
        BEGIN
            -- Kiểm tra: Nếu tất cả tag truyền vào đều không tồn tại trong DB -> Báo lỗi để kích hoạt ROLLBACK
            IF NOT EXISTS (
                SELECT 1 FROM Tags t 
                INNER JOIN STRING_SPLIT(@name_tag, ',') s 
                    ON LOWER(LTRIM(RTRIM(s.value))) = LOWER(LTRIM(RTRIM(t.name)))
            )
            BEGIN
                RAISERROR(N'Thể loại game không hợp lệ hoặc không tồn tại trong hệ thống.', 16, 1);
            END;

            INSERT INTO Games_Tags(game_id, tag_id) 
            SELECT DISTINCT @game_id, t.tag_id 
            FROM Tags t
            INNER JOIN STRING_SPLIT(@name_tag, ',') s
                ON LOWER(LTRIM(RTRIM(s.value))) = LOWER(LTRIM(RTRIM(t.name)));
        END;

        COMMIT TRANSACTION;

        -- 4. Trả về ID game vừa tạo
        SELECT @game_id AS game_id;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@ErrMsg, 16, 1);
    END CATCH;
END;
GO

-- Cập nhật thông tin Game (Atomicity: Đảm bảo không bị mất tags cũ nếu thêm tags mới lỗi)
CREATE OR ALTER PROCEDURE sp_updateGame
    @game_id INT,
    @name NVARCHAR(255),
    @name_tag NVARCHAR(MAX),
    @developer NVARCHAR(255),
    @is_active BIT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NOT EXISTS (SELECT 1 FROM Games WHERE game_id = @game_id)
    BEGIN
        RAISERROR(N'Game không tồn tại trong hệ thống.', 16, 1);
        RETURN;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- 1. Cập nhật thông tin cơ bản của Game
        UPDATE Games
        SET name = @name,
            developer = @developer,
            is_active = @is_active
        WHERE game_id = @game_id;

        -- 2. Cập nhật danh sách thể loại / Tags (Nếu bước insert lỗi thì rollback hoàn lại tag cũ)
        IF @name_tag IS NOT NULL
        BEGIN
            DELETE FROM Games_Tags WHERE game_id = @game_id;

            IF LEN(TRIM(@name_tag)) > 0
            BEGIN
                INSERT INTO Games_Tags (game_id, tag_id)
                SELECT DISTINCT @game_id, t.tag_id
                FROM Tags t
                INNER JOIN STRING_SPLIT(@name_tag, ',') s 
                    ON LOWER(LTRIM(RTRIM(s.value))) = LOWER(LTRIM(RTRIM(t.name)));
            END;
        END;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@ErrMsg, 16, 1);
    END CATCH;
END;
GO

-- Xóa Game (Cascade an toàn trong 1 Transaction, tránh lỗi khóa ngoại FK và dữ liệu mồ côi)
CREATE OR ALTER PROCEDURE sp_deleteGame
    @game_id INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NOT EXISTS (SELECT 1 FROM Games WHERE game_id = @game_id)
    BEGIN
        RAISERROR(N'Game không tồn tại trong hệ thống.', 16, 1);
        RETURN;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- 1. Dọn dẹp các lượt Vote của Đề xuất cấu hình liên quan đến game này
        IF EXISTS (SELECT 1 FROM sys.tables WHERE name = 'Votes') AND EXISTS (SELECT 1 FROM sys.tables WHERE name = 'Game_PC_Recommendation')
        BEGIN
            DELETE v
            FROM Votes v
            JOIN Game_PC_Recommendation gpr ON v.target_id = gpr.recommendation_id
            WHERE v.target_type = 'RECOMMENDATION' AND gpr.game_id = @game_id;
        END;

        -- 2. Xóa các đề xuất cấu hình của game này
        IF EXISTS (SELECT 1 FROM sys.tables WHERE name = 'Game_PC_Recommendation')
        BEGIN
            DELETE FROM Game_PC_Recommendation WHERE game_id = @game_id;
        END;

        -- 3. Dọn dẹp các lượt Vote & Báo cáo vi phạm của Đánh giá (Reviews) thuộc game này
        IF EXISTS (SELECT 1 FROM sys.tables WHERE name = 'Votes') AND EXISTS (SELECT 1 FROM sys.tables WHERE name = 'Reviews')
        BEGIN
            DELETE v
            FROM Votes v
            JOIN Reviews r ON v.target_id = r.review_id
            WHERE v.target_type = 'REVIEW' AND r.game_id = @game_id;
        END;

        IF EXISTS (SELECT 1 FROM sys.tables WHERE name = 'Review_Reports') AND EXISTS (SELECT 1 FROM sys.tables WHERE name = 'Reviews')
        BEGIN
            DELETE rr
            FROM Review_Reports rr
            JOIN Reviews r ON rr.review_id = r.review_id
            WHERE r.game_id = @game_id;
        END;

        -- 4. Xóa đánh giá game (Reviews)
        IF EXISTS (SELECT 1 FROM sys.tables WHERE name = 'Reviews')
        BEGIN
            DELETE FROM Reviews WHERE game_id = @game_id;
        END;

        -- 5. Xóa danh sách yêu thích liên quan đến game (Wishlist)
        IF EXISTS (SELECT 1 FROM sys.tables WHERE name = 'Wishlist')
        BEGIN
            DELETE FROM Wishlist WHERE game_id = @game_id;
        END;

        -- 6. Xóa các ràng buộc thể loại của game (Games_Tags)
        IF EXISTS (SELECT 1 FROM sys.tables WHERE name = 'Games_Tags')
        BEGIN
            DELETE FROM Games_Tags WHERE game_id = @game_id;
        END;

        -- 7. Xóa cấu hình yêu cầu phần cứng của game (Game_requirement)
        IF EXISTS (SELECT 1 FROM sys.tables WHERE name = 'Game_requirement')
        BEGIN
            DELETE FROM Game_requirement WHERE game_id = @game_id;
        END;

        -- 8. Xóa chính bản ghi Game (Nếu có trigger trg_Games_SoftDelete sẽ tự động chuyển is_active = 0, nếu không sẽ xóa cứng)
        DELETE FROM Games WHERE game_id = @game_id;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@ErrMsg, 16, 1);
    END CATCH;
END;
GO 


CREATE OR ALTER PROCEDURE sp_UpdateGameRequirement
    @game_id INT,
    @type VARCHAR(50),             -- 'MINIMUM' hoặc 'RECOMMENDED'
    @os NVARCHAR(100) = NULL,      -- Hệ điều hành
    @cpu_name NVARCHAR(255) = NULL, -- Tên CPU
    @gpu_name NVARCHAR(255) = NULL, -- Tên GPU
    @ram INT = NULL,               -- Dung lượng RAM (GB)
    @storage INT = NULL            -- Dung lượng ổ cứng (GB)
AS
BEGIN
    SET NOCOUNT ON;

    -- 1. Kiểm tra tham số @type có hợp lệ không
    IF UPPER(ISNULL(@type, '')) NOT IN ('MINIMUM', 'RECOMMENDED')
    BEGIN
        SELECT 0 AS success, N'Type phải là MINIMUM hoặc RECOMMENDED' AS message;
        RETURN;
    END;

    -- 2. Tìm cpu_id trong bảng CPUs (khớp chính xác hoặc tìm kiếm chứa từ khóa LIKE)
    DECLARE @cpu_id INT = NULL;
    IF NULLIF(LTRIM(RTRIM(@cpu_name)), '') IS NOT NULL
    BEGIN
        SELECT TOP 1 @cpu_id = cpu_id
        FROM dbo.CPUs
        WHERE LOWER(name) = LOWER(LTRIM(RTRIM(@cpu_name)))
           OR LOWER(name) LIKE '%' + LOWER(LTRIM(RTRIM(@cpu_name))) + '%';
    END;

    -- Nếu CPU nhập vào không khớp tên nào trong DB, gán ID CPU đầu tiên để tránh lỗi Khóa ngoại (FK)
    IF @cpu_id IS NULL AND EXISTS (SELECT 1 FROM dbo.CPUs)
    BEGIN
        SELECT TOP 1 @cpu_id = cpu_id FROM dbo.CPUs;
    END;

    -- 3. Tìm gpu_id trong bảng GPUs (khớp chính xác hoặc tìm kiếm chứa từ khóa LIKE)
    DECLARE @gpu_id INT = NULL;
    IF NULLIF(LTRIM(RTRIM(@gpu_name)), '') IS NOT NULL
    BEGIN
        SELECT TOP 1 @gpu_id = gpu_id
        FROM dbo.GPUs
        WHERE LOWER(name) = LOWER(LTRIM(RTRIM(@gpu_name)))
           OR LOWER(name) LIKE '%' + LOWER(LTRIM(RTRIM(@gpu_name))) + '%';
    END;

    -- Nếu GPU nhập vào không khớp tên nào trong DB, gán ID GPU đầu tiên để tránh lỗi Khóa ngoại (FK)
    IF @gpu_id IS NULL AND EXISTS (SELECT 1 FROM dbo.GPUs)
    BEGIN
        SELECT TOP 1 @gpu_id = gpu_id FROM dbo.GPUs;
    END;

    -- 4. Thực hiện Cập nhật (UPDATE) nếu đã có, hoặc Thêm mới (INSERT) nếu chưa có
    IF EXISTS (
        SELECT 1
        FROM dbo.Game_requirement
        WHERE game_id = @game_id
          AND UPPER(type) = UPPER(@type)
    )
    BEGIN
        -- Cập nhật bản ghi đã tồn tại
        UPDATE dbo.Game_requirement
        SET os = ISNULL(NULLIF(LTRIM(RTRIM(@os)), ''), os),
            ram = ISNULL(@ram, ram),
            storage = ISNULL(@storage, storage),
            cpu_id = ISNULL(@cpu_id, cpu_id),
            gpu_id = ISNULL(@gpu_id, gpu_id)
        WHERE game_id = @game_id
          AND UPPER(type) = UPPER(@type);
    END
    ELSE
    BEGIN
        -- Thêm mới bản ghi nếu chưa có (dùng ISNULL gán mặc định nếu thiếu thông số)
        INSERT INTO dbo.Game_requirement
        (
            game_id,
            type,
            os,
            ram,
            storage,
            cpu_id,
            gpu_id
        )
        VALUES
        (
            @game_id,
            UPPER(@type),
            ISNULL(NULLIF(LTRIM(RTRIM(@os)), ''), N'Windows 10 64-bit'),
            ISNULL(@ram, 8),
            ISNULL(@storage, 50),
            @cpu_id,
            @gpu_id
        );
    END;

    -- Trả về phản hồi thành công cho API Node.js
    SELECT 1 AS success, N'Cập nhật thông tin cấu hình game thành công' AS message;
END;