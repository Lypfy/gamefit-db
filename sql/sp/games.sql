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

    -- 1. Thêm game vào bảng Games (Bao gồm cả cột image)
    INSERT INTO Games(name, description, publisher, developer, release_date, download_url, image) 
    VALUES (@name, @description, @publisher, @developer, @release_date, @download_url, @image);

    -- 2. Lấy ID game vừa tạo
    DECLARE @game_id INT;
    SET @game_id = SCOPE_IDENTITY();

    -- 3. Gán các tag cho game
    IF @name_tag IS NOT NULL AND LEN(TRIM(@name_tag)) > 0
    BEGIN
        INSERT INTO Games_Tags(game_id, tag_id) 
        SELECT DISTINCT @game_id, t.tag_id 
        FROM Tags t
        INNER JOIN STRING_SPLIT(@name_tag, ',') s
            ON LOWER(LTRIM(RTRIM(s.value))) = LOWER(LTRIM(RTRIM(t.name)));
    END
    SELECT @game_id AS game_id
END
GO

-- Cập nhật
CREATE  OR ALTER PROCEDURE sp_updateGame
    @game_id INT,
    @name NVARCHAR(255),
    @name_tag NVARCHAR(MAX),
    @developer NVARCHAR(255),
    @is_active BIT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE Games
    SET name = @name,
        developer = @developer,
        is_active = @is_active
    WHERE game_id = @game_id;

    IF @name_tag IS NOT NULL
    BEGIN
        DELETE FROM Games_Tags WHERE game_id = @game_id;

        INSERT INTO Games_Tags (game_id, tag_id)
        SELECT DISTINCT @game_id, t.tag_id
        FROM Tags t
        INNER JOIN STRING_SPLIT(@name_tag, ',') s ON LOWER(LTRIM(RTRIM(s.value))) = LOWER(LTRIM(RTRIM(t.name)));
    END
END;
GO

-- Xóa
CREATE OR ALTER PROCEDURE sp_deleteGame
    @game_id INT
AS
BEGIN
    SET NOCOUNT ON;
    DELETE FROM Games
    WHERE game_id = @game_id;
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