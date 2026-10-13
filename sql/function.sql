/* - Mục lục
        + Auth
        + Games 
        + Tags
        + Cpus
        + Gpus
        + Game_requirement
        + ComputerConfig
        + Wishlist
        + Reviews
*/ 
-- Auth
-- Kiểm tra sự tồn tại của tài khoản 
CREATE OR ALTER FUNCTION fn_checkUserByEmail (@email VARCHAR(100))
RETURNS TABLE
AS
    RETURN (
        SELECT u.user_id, u.user_name, u.email, u.password, u.status, u.role
        FROM Users u
        WHERE u.email = @email
    )
GO

CREATE OR ALTER  FUNCTION fn_GetUsers
(
    @keyword NVARCHAR(100) = NULL,
    @role NVARCHAR(50) = NULL,   
    @status NVARCHAR(50) = NULL 
)
RETURNS TABLE
AS
RETURN
(
    SELECT 
        user_id,
        user_name,
        email,
        role,
        create_at,
        status,
        lock_until,
        lock_reason
    FROM Users
    WHERE 
        (
            @keyword IS NULL 
            OR @keyword = N'' 
            OR user_name LIKE N'%' + @keyword + N'%' 
            OR email LIKE N'%' + @keyword + N'%'
        )
        AND (@role IS NULL OR @role = N'' OR role = @role)
        AND (@status IS NULL OR @status = N'' OR status = @status)
);
GO 

-- user
-- 0: false, 1: true
-- FUNCTION
-- Đăng nhập
CREATE OR ALTER FUNCTION fn_Login(@user_name VARCHAR(50), @email VARCHAR(100), @password VARCHAR(255))
RETURNS TABLE
AS
    RETURN (
        SELECT u.user_id, u.user_name, u.email, u.password, u.status, u.role
        FROM Users u
        WHERE u.user_name = @user_name OR u.email = @email
    )
GO

-- Games
CREATE OR ALTER FUNCTION fn_GetGames(  
    @offset INT,   
    @limit INT,  
    @categories NVARCHAR(MAX) = NULL,  
    @publishers NVARCHAR(MAX) = NULL,  
    @rams NVARCHAR(MAX) = NULL  
)    
RETURNS TABLE    
AS    
RETURN    
(    
    SELECT     
        v.game_id,    
        v.game_name AS name,    
        v.image,
        v.trailer_url, 
        v.average_rating AS rating,  
        v.tags  
    FROM vw_Game_Card v
    JOIN Games g ON v.game_id = g.game_id -- JOIN để lấy field 'publisher' lọc
    WHERE   
        -- Lọc theo Publisher  
        (@publishers IS NULL OR @publishers = '' OR g.publisher IN (SELECT TRIM(value) FROM STRING_SPLIT(@publishers, ',')))  
        AND  
          
        -- Lọc theo Categories (Điều kiện OR: Game có ÍT NHẤT 1 tag khớp với danh sách truyền vào)  
        (@categories IS NULL OR @categories = '' OR EXISTS (
            SELECT 1
            FROM Games_Tags gt2
            JOIN Tags t2 ON gt2.tag_id = t2.tag_id
            WHERE gt2.game_id = v.game_id
              AND t2.name IN (SELECT TRIM(value) FROM STRING_SPLIT(@categories, ','))
              AND (t2.is_hidden = 0 OR t2.is_hidden IS NULL)
        )) 
        AND  
          
        -- Lọc theo RAM   
        (@rams IS NULL OR @rams = '' OR EXISTS (  
            SELECT 1 FROM Game_requirement gr  
            WHERE gr.game_id = v.game_id   
            AND gr.type = 'MINIMUM'  
            AND gr.ram IN (SELECT TRIM(value) FROM STRING_SPLIT(@rams, ','))  
        ))  
    ORDER BY v.game_id    
    OFFSET @offset ROWS    
    FETCH NEXT @limit ROWS ONLY    
);
GO

CREATE OR ALTER FUNCTION fn_GetGameDetail(@game_id INT)  
RETURNS TABLE  
AS  
RETURN(  
    SELECT 
        game_id, 
        game_name AS name, 
        description, 
        publisher, 
        developer, 
        platform, 
        release_date, 
        image, 
        download_url,  
        trailer_url, 
        tags
    FROM vw_Game_Detail 
    WHERE game_id = @game_id 
);
GO 

CREATE OR ALTER FUNCTION fn_GetGamesByTag(@tag_name NVARCHAR(50))    
RETURNS TABLE    
AS    
RETURN    
(    
    SELECT      
        v.game_id,     
        v.game_name AS name,     
        v.image,     
        v.trailer_url,
        v.average_rating AS rating,  
        v.tags
    FROM vw_Game_Card v    
    INNER JOIN Games_Tags gt ON v.game_id = gt.game_id     
    INNER JOIN Tags t ON gt.tag_id = t.tag_id
    WHERE t.name = @tag_name AND t.is_hidden = 0
);
GO


-- Kiểm tra sự tồn tại của game
CREATE OR ALTER FUNCTION fn_CheckGameExist(@game_id INT)
RETURNS BIT 
AS
BEGIN   
    IF EXISTS (SELECT 1 FROM Games WHERE game_id = @game_id)
        RETURN 1;
    RETURN 0;
END
GO 

CREATE OR ALTER FUNCTION fn_GetAverageRating (@game_id INT)
RETURNS REAL
AS
BEGIN
    DECLARE @avg REAL;
    SELECT @avg = CAST(average_rating AS REAL)
    FROM vw_Game_Detail
    WHERE game_id = @game_id;

    RETURN ISNULL(@avg, 0);
END
GO 

CREATE OR ALTER FUNCTION [dbo].[fn_GetCompatibilityPercent]
(
    @game_id INT,
    @cpu_name VARCHAR(100),
    @gpu_name VARCHAR(100),
    @ram INT,
    @storage INT,
    @os VARCHAR(100)
)
RETURNS DECIMAL(5,2)
AS
BEGIN
    DECLARE
        @user_cpu_score FLOAT,
        @user_gpu_score FLOAT,

        @min_cpu_score FLOAT,
        @rec_cpu_score FLOAT,
        @min_gpu_score FLOAT,
        @rec_gpu_score FLOAT,

        @min_ram INT,
        @rec_ram INT,
        @min_storage INT,
        @rec_storage INT,
        @min_os VARCHAR(100),

        @cpu_percent FLOAT = 0,
        @gpu_percent FLOAT = 0,
        @ram_percent FLOAT = 0,
        @storage_percent FLOAT = 0,
        @os_percent FLOAT = 0,
        @total_percent FLOAT = 0;

    -- 1. Lấy điểm benchmark người dùng
    SELECT @user_cpu_score = benchmark_score FROM dbo.Cpus WHERE [name] = @cpu_name;
    SELECT @user_gpu_score = benchmark_score FROM dbo.Gpus WHERE [name] = @gpu_name;

    IF @user_cpu_score IS NULL OR @user_gpu_score IS NULL
        RETURN 0.00;

    -- 2. Lấy cấu hình yêu cầu của game
    SELECT 
        @min_ram     = MAX(CASE WHEN r.type = 'MINIMUM' THEN r.ram END),
        @rec_ram     = MAX(CASE WHEN r.type = 'RECOMMENDED' THEN r.ram END),
        @min_storage = MAX(CASE WHEN r.type = 'MINIMUM' THEN r.storage END),
        @rec_storage = MAX(CASE WHEN r.type = 'RECOMMENDED' THEN r.storage END),
        @min_os      = MAX(CASE WHEN r.type = 'MINIMUM' THEN r.os END),

        @min_cpu_score = MAX(CASE WHEN r.type = 'MINIMUM' THEN c.benchmark_score END),
        @rec_cpu_score = MAX(CASE WHEN r.type = 'RECOMMENDED' THEN c.benchmark_score END),

        @min_gpu_score = MAX(CASE WHEN r.type = 'MINIMUM' THEN g.benchmark_score END),
        @rec_gpu_score = MAX(CASE WHEN r.type = 'RECOMMENDED' THEN g.benchmark_score END)
    FROM dbo.Game_requirement r
    LEFT JOIN dbo.Cpus c ON c.cpu_id = r.cpu_id
    LEFT JOIN dbo.Gpus g ON g.gpu_id = r.gpu_id
    WHERE r.game_id = @game_id;

    -- Nếu game thiếu dữ liệu tối thiểu
    IF @min_cpu_score IS NULL OR @min_gpu_score IS NULL OR @min_ram IS NULL
        RETURN 0.00;

    -- Xử lý nếu game không có RECOMMENDED: Tự giả định Rec = 1.35 * Min để có dải phân hóa
    IF @rec_cpu_score IS NULL OR @rec_cpu_score <= @min_cpu_score SET @rec_cpu_score = @min_cpu_score * 1.35;
    IF @rec_gpu_score IS NULL OR @rec_gpu_score <= @min_gpu_score SET @rec_gpu_score = @min_gpu_score * 1.35;
    IF @rec_ram IS NULL OR @rec_ram <= @min_ram SET @rec_ram = @min_ram * 2;
    IF @rec_storage IS NULL OR @rec_storage <= @min_storage SET @rec_storage = @min_storage;

    -- 3. Kiểm tra OS
    DECLARE @min_os_clean VARCHAR(100) = LOWER(LTRIM(RTRIM(ISNULL(@min_os, ''))));
    DECLARE @user_os_clean VARCHAR(100) = LOWER(LTRIM(RTRIM(ISNULL(@os, ''))));
    SET @min_os_clean = REPLACE(@min_os_clean, '-', ' ');
    SET @user_os_clean = REPLACE(@user_os_clean, '-', ' ');

    DECLARE @min_family VARCHAR(20) = CASE 
        WHEN @min_os_clean LIKE '%windows 11%' OR @min_os_clean LIKE '%win 11%' THEN 'win11'
        WHEN @min_os_clean LIKE '%windows 10%' OR @min_os_clean LIKE '%win 10%' THEN 'win10'
        WHEN @min_os_clean LIKE '%windows%' OR @min_os_clean LIKE '%win%' THEN 'win_general'
        WHEN @min_os_clean LIKE '%macos%' OR @min_os_clean LIKE '%mac os%' OR @min_os_clean = 'os' OR @min_os_clean LIKE 'os %' THEN 'macos'
        WHEN @min_os_clean LIKE '%linux%' OR @min_os_clean LIKE '%ubuntu%' THEN 'linux'
        WHEN @min_os_clean = '' THEN 'any'
        ELSE 'other'
    END;

    DECLARE @user_family VARCHAR(20) = CASE 
        WHEN @user_os_clean LIKE '%windows 11%' OR @user_os_clean LIKE '%win 11%' THEN 'win11'
        WHEN @user_os_clean LIKE '%windows 10%' OR @user_os_clean LIKE '%win 10%' THEN 'win10'
        WHEN @user_os_clean LIKE '%windows%' OR @user_os_clean LIKE '%win%' THEN 'win_general'
        WHEN @user_os_clean LIKE '%macos%' OR @user_os_clean LIKE '%mac os%' OR @user_os_clean = 'os' OR @user_os_clean LIKE 'os %' THEN 'macos'
        WHEN @user_os_clean LIKE '%linux%' OR @user_os_clean LIKE '%ubuntu%' THEN 'linux'
        ELSE 'unknown'
    END;

    DECLARE @bit_compatible BIT = CASE 
        WHEN @min_os_clean LIKE '%64%' AND @user_os_clean NOT LIKE '%64%' THEN 0
        ELSE 1
    END;

    IF (@min_family = 'any' OR @min_os_clean = '')
       OR (
           @bit_compatible = 1 AND (
               (@min_family = 'win10' AND @user_family IN ('win10', 'win11'))
               OR (@min_family = 'win11' AND @user_family = 'win11')
               OR (@min_family = 'win_general' AND @user_family IN ('win10', 'win11', 'win_general'))
               OR (@min_family = 'macos' AND @user_family = 'macos')
               OR (@min_family = 'linux' AND @user_family = 'linux')
           )
       )
    BEGIN
        SET @os_percent = 100.0;
    END
    ELSE
    BEGIN
        SET @os_percent = 0.0;
    END

     IF  @ram < @min_ram 
       OR @storage < @min_storage 
       OR @os_percent < 100
    BEGIN
        RETURN CAST(10.00 AS DECIMAL(5,2));
    END

    -- 4. Tính điểm nội suy liên tục cho từng linh kiện (Không bao giờ bị âm)
    -- CPU
    IF @user_cpu_score < @min_cpu_score
        SET @cpu_percent = (@user_cpu_score / NULLIF(@min_cpu_score, 0)) * 50.0;
    ELSE IF @user_cpu_score >= @rec_cpu_score
        SET @cpu_percent = 100.0;
    ELSE
        SET @cpu_percent = 50.0 + (@user_cpu_score - @min_cpu_score) * 50.0 / (@rec_cpu_score - @min_cpu_score);

    -- GPU
    IF @user_gpu_score < @min_gpu_score
        SET @gpu_percent = (@user_gpu_score / NULLIF(@min_gpu_score, 0)) * 50.0;
    ELSE IF @user_gpu_score >= @rec_gpu_score
        SET @gpu_percent = 100.0;
    ELSE
        SET @gpu_percent = 50.0 + (@user_gpu_score - @min_gpu_score) * 50.0 / (@rec_gpu_score - @min_gpu_score);

    -- RAM
    IF @ram < @min_ram
        SET @ram_percent = (CAST(@ram AS FLOAT) / NULLIF(@min_ram, 0)) * 50.0;
    ELSE IF @ram >= @rec_ram
        SET @ram_percent = 100.0;
    ELSE
        SET @ram_percent = 50.0 + (CAST(@ram - @min_ram AS FLOAT)) * 50.0 / (@rec_ram - @min_ram);

    -- Storage
    IF @storage < @min_storage
        SET @storage_percent = (CAST(@storage AS FLOAT) / NULLIF(@min_storage, 0)) * 50.0;
    ELSE IF @storage >= @rec_storage
        SET @storage_percent = 100.0;
    ELSE
        SET @storage_percent = 50.0 + (CAST(@storage - @min_storage AS FLOAT)) * 50.0 / (@rec_storage - @min_storage);

    -- 5. Tổng hợp trọng số
    SET @total_percent =
          @cpu_percent * 0.25
        + @gpu_percent * 0.35
        + @ram_percent * 0.20
        + @storage_percent * 0.10
        + @os_percent * 0.10;

    IF @total_percent > 100.0 SET @total_percent = 100.0;
    IF @total_percent < 0.0   SET @total_percent = 0.0;

    RETURN CAST(@total_percent AS DECIMAL(5,2));
END;
GO

CREATE OR ALTER FUNCTION fn_TotalGames(
    @categories NVARCHAR(MAX) = NULL,
    @publishers NVARCHAR(MAX) = NULL,
    @rams NVARCHAR(MAX) = NULL
)
RETURNS INT
AS
BEGIN
    DECLARE @total INT;
    SELECT @total = COUNT(DISTINCT g.game_id)
    FROM Games g
    WHERE 
        g.is_active = 1 AND
        (@publishers IS NULL OR @publishers = '' OR g.publisher IN (SELECT TRIM(value) FROM STRING_SPLIT(@publishers, ',')))
        AND
        (@categories IS NULL OR @categories = '' OR EXISTS (
            SELECT 1
            FROM Games_Tags gt2
            JOIN Tags t2 ON gt2.tag_id = t2.tag_id
            WHERE gt2.game_id = g.game_id
              AND t2.name IN (SELECT TRIM(value) FROM STRING_SPLIT(@categories, ','))
              AND t2.is_hidden = 0
        ))
        AND
        (@rams IS NULL OR @rams = '' OR EXISTS (
            SELECT 1 FROM Game_requirement gr
            WHERE gr.game_id = g.game_id 
            AND gr.type = 'MINIMUM'
            AND gr.ram IN (SELECT TRIM(value) FROM STRING_SPLIT(@rams, ','))
        ));
    RETURN @total;
END;
GO

-- Tags
CREATE OR ALTER FUNCTION fn_SearchTagsWithGameCount(@search NVARCHAR(100) = NULL)
RETURNS TABLE
AS
RETURN
(
    SELECT 
        t.tag_id, 
        t.name, 
        COUNT(gt.game_id) AS soluonggame
    FROM Tags t
    LEFT JOIN Games_Tags gt ON t.tag_id = gt.tag_id
    WHERE t.is_hidden = 0 AND (@search IS NULL 
       OR @search = '' 
       OR t.name LIKE '%' + @search + '%')
    GROUP BY t.tag_id, t.name
);
GO 

-- Cpus
-- 1. Hàm lấy thông tin CPU theo ID (nếu truyền NULL hoặc 0 sẽ trả về toàn bộ CPU)
CREATE OR ALTER FUNCTION dbo.fn_GetCpus(@cpu_id INT = NULL)
RETURNS TABLE
AS
RETURN (
    SELECT cpu_id, name, brand, benchmark_score
    FROM vw_Cpu_Detail
    WHERE (@cpu_id IS NULL OR @cpu_id = 0 OR cpu_id = @cpu_id)
);
GO

-- 2. Hàm tìm kiếm CPU theo tên hoặc hãng (dùng cho tìm kiếm và phân trang)
CREATE OR ALTER FUNCTION dbo.fn_SearchCpus(@search NVARCHAR(100) = '')
RETURNS TABLE
AS
RETURN (
    SELECT cpu_id, name, brand, benchmark_score
    FROM vw_Cpu_Detail
    WHERE (@search IS NULL OR @search = '' OR name LIKE '%' + @search + '%' OR brand LIKE '%' + @search + '%')
);
GO 

-- Gpus
-- 1. Hàm lấy GPU theo ID (hoặc tất cả GPU khi @gpu_id là NULL / 0)
CREATE OR ALTER  FUNCTION dbo.fn_GetGpus(@gpu_id INT = NULL)
RETURNS TABLE
AS
RETURN (
    SELECT gpu_id, name, brand, benchmark_score
    FROM vw_Gpu_Detail 
    WHERE (@gpu_id IS NULL OR @gpu_id = 0 OR gpu_id = @gpu_id)
);
GO 

-- 2. Hàm tìm kiếm GPU theo tên hoặc hãng (dùng cho phân trang và tìm kiếm)
CREATE OR ALTER FUNCTION dbo.fn_SearchGpus(@search NVARCHAR(100) = '')
RETURNS TABLE
AS
RETURN (
    SELECT gpu_id, name, brand, benchmark_score
    FROM vw_Gpu_Detail
    WHERE (@search IS NULL OR @search = '' OR name LIKE '%' + @search + '%' OR brand LIKE '%' + @search + '%')
);
GO 

-- Game_requirement
CREATE OR ALTER FUNCTION fn_GetGameRequirementByID(@game_id INT)
RETURNS TABLE
AS
    RETURN (
        SELECT cpu_name, gpu_name, os, ram, storage, type 
        FROM vw_Game_Requirement_Detail 
        WHERE game_id = @game_id
    )
GO

-- ComputerConfig
-- 3.Tra cứu cấu hình máy (Thay thế bằng vw_User_PC_Detail)
CREATE OR ALTER FUNCTION fn_GetComputersConfig(@user_id INT)
RETURNS TABLE
AS
    RETURN(
        SELECT pc_id, pc_name, cpu_name, gpu_name, user_ram AS ram, user_storage AS storage, user_os AS os
        FROM vw_User_PC_Detail
        WHERE user_id = @user_id 
    )
GO 

-- Wishlist
-- 9. Tìm kiếm game trong Wishlist (Thay bằng vw_Game_Card)
CREATE OR ALTER FUNCTION fn_GetGamesFromWishlist(@user_id INT)
RETURNS TABLE
AS
    RETURN (
        SELECT v.*, w.added_at
        FROM Wishlist w
        JOIN vw_Game_Card v ON w.game_id = v.game_id
        WHERE w.user_id = @user_id
    )
GO 

-- Reviews
CREATE OR ALTER FUNCTION fn_getReviews (@game_id INT, @current_user_id INT = NULL) 
RETURNS TABLE
AS
    RETURN (
        SELECT 
            r.review_id, 
            r.user_id, 
            u.user_name, 
            r.rating, 
            r.comment, 
            r.created_at,
            ISNULL(r.is_hidden, 0) AS is_hidden
        FROM Reviews r
        JOIN Users u ON r.user_id = u.user_id
        JOIN Games g ON r.game_id = g.game_id
        WHERE r.game_id = @game_id 
          AND g.is_active = 1
          AND (ISNULL(r.is_hidden, 0) = 0 OR (@current_user_id IS NOT NULL AND r.user_id = @current_user_id))
    )
GO 
