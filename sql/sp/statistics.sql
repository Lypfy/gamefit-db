-- ============================================================================
-- GAMEFIT - STORED PROCEDURES CHO MODULE THỐNG KÊ ADMIN (ADMIN STATISTICS)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. THỦ TỤC THỐNG KÊ THỂ LOẠI (GENRE STATISTICS)
-- Trả về 2 bảng kết quả:
--   Bảng 1: Tổng số game, tổng số thể loại, tổng lượt wishlist
--   Bảng 2: Danh sách chi tiết từng thể loại kèm số game, lượt wishlist, điểm đánh giá TB
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_GetGenreStatistics
AS
BEGIN
    SET NOCOUNT ON;

    -- Bảng kết quả 1: Tổng quan số lượng
    SELECT 
        (SELECT COUNT(*) FROM Games) AS total_games,
        (SELECT COUNT(DISTINCT tag_id) FROM Games_Tags) AS total_genres,
        (SELECT COUNT(*) FROM Wishlist) AS total_wishlists;

    -- Bảng kết quả 2: Chi tiết phân bổ theo thể loại
    WITH GameStats AS (
        SELECT 
            game_id,
            (SELECT COUNT(*) FROM Wishlist w WHERE w.game_id = g.game_id) AS total_wishlist,
            (SELECT COUNT(*) FROM Reviews r WHERE r.game_id = g.game_id AND r.is_hidden = 0) AS total_review,
            (SELECT AVG(CAST(rating AS FLOAT)) FROM Reviews r WHERE r.game_id = g.game_id AND r.is_hidden = 0) AS avg_rating
        FROM Games g
    )
    SELECT 
        t.tag_id,
        t.name AS genre_name,
        COUNT(gt.game_id) AS game_count,
        ISNULL(SUM(gs.total_wishlist), 0) AS wishlist_count,
        ISNULL(ROUND(AVG(gs.avg_rating), 1), 0) AS avg_rating,
        ISNULL(SUM(gs.total_review), 0) AS review_count
    FROM Tags t
    LEFT JOIN Games_Tags gt ON t.tag_id = gt.tag_id
    LEFT JOIN GameStats gs ON gt.game_id = gs.game_id
    GROUP BY t.tag_id, t.name
    HAVING COUNT(gt.game_id) > 0
    ORDER BY game_count DESC;
END;
GO

-- ----------------------------------------------------------------------------
-- 2. THỦ TỤC THỐNG KÊ WISHLIST & ĐÁNH GIÁ (WISHLIST & REVIEW STATISTICS)
-- Tham số: @limit (mặc định lấy 10 game dẫn đầu)
-- Trả về 3 bảng kết quả:
--   Bảng 1: Tổng số mục lưu, số game trong wishlist, số user có wishlist
--   Bảng 2: Danh sách Top game được đưa vào Wishlist nhiều nhất (kèm ảnh và thể loại)
--   Bảng 3: Danh sách Top game được đánh giá nhiều nhất (kèm ảnh, thể loại, điểm TB)
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_GetWishlistStatistics
    @limit INT = 10
AS
BEGIN
    SET NOCOUNT ON;

    IF @limit IS NULL OR @limit <= 0
        SET @limit = 10;

    -- Bảng kết quả 1: Tổng quan số lượng Wishlist
    SELECT 
        COUNT(*) AS total_wishlist_items,
        COUNT(DISTINCT game_id) AS total_games_in_wishlist,
        COUNT(DISTINCT user_id) AS total_users_with_wishlist
    FROM Wishlist;

    -- Bảng kết quả 2: Top game được wishlist nhiều nhất 
    SELECT TOP (@limit)
        c.game_id,
        c.game_name AS name,
        c.image,
        c.release_date,
        (SELECT COUNT(*) FROM Wishlist w WHERE w.game_id = c.game_id) AS wishlist_count,
        c.tags AS genres
    FROM vw_Game_Card c
    WHERE EXISTS (SELECT 1 FROM Wishlist w WHERE w.game_id = c.game_id)
    ORDER BY wishlist_count DESC, c.game_name ASC;

    -- Bảng kết quả 3: Top game được đánh giá nhiều nhất
    SELECT TOP (@limit)
        c.game_id,
        c.game_name AS name,
        c.image,
        (SELECT COUNT(*) FROM Reviews r WHERE r.game_id = c.game_id AND r.is_hidden = 0) AS review_count,
        c.average_rating AS avg_rating,
        c.tags AS genres
    FROM vw_Game_Card c
    WHERE EXISTS (SELECT 1 FROM Reviews r WHERE r.game_id = c.game_id AND r.is_hidden = 0)
    ORDER BY review_count DESC, c.average_rating DESC, c.game_name ASC;
END;
GO

-- ----------------------------------------------------------------------------
-- 3. THỦ TỤC THỐNG KÊ PHẦN CỨNG (HARDWARE INSIGHTS)
-- Trả về 6 bảng kết quả:
--   Bảng 1: Tổng số CPU, GPU trong kho và số máy cấu hình người dùng
--   Bảng 2: Thị phần CPU (Intel vs AMD)
--   Bảng 3: Thị phần GPU (NVIDIA, AMD, Intel, Apple, Khác)
--   Bảng 4: Top 5 CPU người dùng cấu hình nhiều nhất
--   Bảng 5: Top 5 GPU người dùng cấu hình nhiều nhất
--   Bảng 6: Phân bố dung lượng RAM (<=8GB, 12GB, 16GB, 32GB, >32GB)
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_GetHardwareStatistics
    @limit INT = 20
AS
BEGIN
    SET NOCOUNT ON;

    IF @limit IS NULL OR @limit <= 0
        SET @limit = 20;

    -- Bảng 1: Tổng quan số lượng
    SELECT 
        (SELECT COUNT(*) FROM Cpus) AS total_cpus,
        (SELECT COUNT(*) FROM Gpus) AS total_gpus,
        (SELECT COUNT(*) FROM User_pc WHERE ISNULL(is_deleted, 0) = 0) AS total_user_pcs;

    -- Bảng 2: Thị phần thương hiệu CPU
    SELECT 
        LTRIM(RTRIM(brand)) AS brand,
        COUNT(*) AS count
    FROM Cpus
    WHERE brand IS NOT NULL AND LTRIM(RTRIM(brand)) <> ''
    GROUP BY LTRIM(RTRIM(brand))
    ORDER BY count DESC;

    -- Bảng 3: Thị phần thương hiệu GPU
    SELECT 
        CASE 
            WHEN UPPER(brand) LIKE '%NVIDIA%' THEN 'NVIDIA'
            WHEN UPPER(brand) LIKE '%AMD%' THEN 'AMD'
            WHEN UPPER(brand) LIKE '%INTEL%' THEN 'Intel'
            WHEN UPPER(brand) LIKE '%APPLE%' THEN 'Apple'
            ELSE 'Other'
        END AS brand,
        COUNT(*) AS count
    FROM Gpus
    WHERE brand IS NOT NULL AND LTRIM(RTRIM(brand)) <> ''
    GROUP BY 
        CASE 
            WHEN UPPER(brand) LIKE '%NVIDIA%' THEN 'NVIDIA'
            WHEN UPPER(brand) LIKE '%AMD%' THEN 'AMD'
            WHEN UPPER(brand) LIKE '%INTEL%' THEN 'Intel'
            WHEN UPPER(brand) LIKE '%APPLE%' THEN 'Apple'
            ELSE 'Other'
        END
    ORDER BY count DESC;

    -- Bảng 4: Top CPU được người dùng cấu hình nhiều nhất
    SELECT TOP (@limit)
        c.cpu_id,
        c.name,
        LTRIM(RTRIM(c.brand)) AS brand,
        c.benchmark_score,
        COUNT(up.pc_id) AS user_count
    FROM User_pc up 
    JOIN Cpus c ON up.cpu_id = c.cpu_id 
    WHERE ISNULL(up.is_deleted, 0) = 0
    GROUP BY c.cpu_id, c.name, c.brand, c.benchmark_score
    ORDER BY user_count DESC, c.benchmark_score DESC;

    -- Bảng 5: Top GPU được người dùng cấu hình nhiều nhất
    SELECT TOP (@limit)
        g.gpu_id,
        g.name,
        LTRIM(RTRIM(g.brand)) AS brand,
        g.benchmark_score,
        COUNT(up.pc_id) AS user_count
    FROM User_pc up 
    JOIN Gpus g ON up.gpu_id = g.gpu_id 
    WHERE ISNULL(up.is_deleted, 0) = 0
    GROUP BY g.gpu_id, g.name, g.brand, g.benchmark_score
    ORDER BY user_count DESC, g.benchmark_score DESC;

    -- Bảng 6: Phân bố dung lượng RAM của các máy người dùng
    SELECT 
        CASE 
            WHEN ram <= 8 THEN '<= 8 GB'
            WHEN ram > 8 AND ram <= 12 THEN '12 GB'
            WHEN ram > 12 AND ram <= 16 THEN '16 GB'
            WHEN ram > 16 AND ram <= 32 THEN '32 GB'
            ELSE '> 32 GB'
        END AS ram_tier,
        COUNT(*) AS count
    FROM User_pc 
    WHERE ram IS NOT NULL AND ram > 0 AND ISNULL(is_deleted, 0) = 0
    GROUP BY 
        CASE 
            WHEN ram <= 8 THEN '<= 8 GB'
            WHEN ram > 8 AND ram <= 12 THEN '12 GB'
            WHEN ram > 12 AND ram <= 16 THEN '16 GB'
            WHEN ram > 16 AND ram <= 32 THEN '32 GB'
            ELSE '> 32 GB'
        END
    ORDER BY count DESC;
END;
GO

-- ----------------------------------------------------------------------------
-- 4. THỦ TỤC THỐNG KÊ TỔNG QUAN (GENERAL OVERVIEW - TAB 1)
-- Trả về 4 bảng kết quả:
--   Bảng 1: KPI tổng số game, đang hoạt động, ngừng hoạt động
--   Bảng 2: Biến động phát hành game theo các năm (Timeline / Trend)
--   Bảng 3: Trạng thái game (Active vs Inactive cho Donut Chart)
--   Bảng 4: Danh sách game mới thêm gần đây (TOP @limit)
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_GetGeneralStatistics
    @limit INT = 20
AS
BEGIN
    SET NOCOUNT ON;

    IF @limit IS NULL OR @limit <= 0
        SET @limit = 20;

    -- Bảng 1: Tổng quan số lượng game theo trạng thái
    SELECT 
        COUNT(*) AS total_games,
        ISNULL(SUM(CASE WHEN is_active = 1 THEN 1 ELSE 0 END), 0) AS active_games,
        ISNULL(SUM(CASE WHEN is_active = 0 THEN 1 ELSE 0 END), 0) AS inactive_games
    FROM Games;

    -- Bảng 2: Biến động số lượng game theo 7 năm gần nhất
    SELECT *
    FROM (
        SELECT TOP 7
            YEAR(release_date) AS [year],
            COUNT(*) AS count
        FROM Games
        WHERE release_date IS NOT NULL
        GROUP BY YEAR(release_date)
        ORDER BY [year] DESC
    ) sub
    ORDER BY [year] ASC;

    -- Bảng 3: Trạng thái game (để vẽ Donut chart)
    SELECT 
        N'Đang hoạt động' AS status_name,
        ISNULL(SUM(CASE WHEN is_active = 1 THEN 1 ELSE 0 END), 0) AS count
    FROM Games
    UNION ALL
    SELECT 
        N'Ngừng hoạt động' AS status_name,
        ISNULL(SUM(CASE WHEN is_active = 0 THEN 1 ELSE 0 END), 0) AS count
    FROM Games;

    -- Bảng 4: Game được thêm gần đây (TOP @limit) - Dùng vw_Game_Card
    SELECT TOP (@limit)
        c.game_id,
        c.game_name AS name,
        c.image,
        c.release_date,
        g.is_active,
        c.tags AS genres
    FROM vw_Game_Card c
    JOIN Games g ON c.game_id = g.game_id
    ORDER BY c.game_id DESC;
END;
GO


