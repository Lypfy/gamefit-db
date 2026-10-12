-- VIEW GPU
CREATE OR ALTER VIEW vw_Gpu_Detail AS
SELECT 
    gpu_id, 
    name, 
    name AS gpu_name, 
    brand, 
    benchmark_score
FROM Gpus;
GO

-- VIEW CPU
CREATE OR ALTER VIEW vw_Cpu_Detail AS
SELECT 
    cpu_id, 
    name, 
    name AS cpu_name, 
    brand, 
    benchmark_score
FROM Cpus;
GO

-- User
CREATE OR ALTER VIEW vw_User_Safe_Profile AS
SELECT 
    user_id, 
    user_name, 
    role, 
    create_at, 
    status
FROM Users;
GO

-- Games: 
--  + vw_Game_Card
--  + vw_Game_Detail 
CREATE OR ALTER VIEW vw_Game_Card AS
SELECT 
    g.game_id, 
    g.name AS game_name, 
    g.image,
    g.trailer_url,
    g.release_date,
    g.is_active,
    ISNULL(r.average_rating, 0) AS average_rating,
    (
        SELECT STRING_AGG(t.name, ', ') 
        FROM Games_Tags gt
        JOIN Tags t ON gt.tag_id = t.tag_id
        WHERE gt.game_id = g.game_id AND t.is_hidden = 0
    ) AS tags
FROM Games g
LEFT JOIN (
    SELECT game_id, CAST(AVG(CAST(rating AS FLOAT)) AS DECIMAL(2,1)) AS average_rating
    FROM Reviews
    WHERE is_hidden = 0
    GROUP BY game_id
) r ON g.game_id = r.game_id
WHERE g.is_active = 1
GO 

CREATE OR ALTER VIEW vw_Game_Detail AS
SELECT 
    g.game_id, 
    g.name AS game_name, 
    g.description,
    g.publisher,
    g.developer,
    g.platform,
    g.release_date,
    g.image,
    g.trailer_url,
    g.download_url,
    ISNULL(r.average_rating, 0) AS average_rating,
    ISNULL(r.total_reviews, 0) AS total_reviews,
    (
        SELECT STRING_AGG(t.name, ', ') 
        FROM Games_Tags gt
        JOIN Tags t ON gt.tag_id = t.tag_id
        WHERE gt.game_id = g.game_id AND t.is_hidden = 0
    ) AS tags
FROM Games g
LEFT JOIN (
    SELECT 
        game_id, 
        CAST(AVG(CAST(rating AS FLOAT)) AS DECIMAL(2,1)) AS average_rating,
        COUNT(review_id) AS total_reviews
    FROM Reviews
    WHERE is_hidden = 0
    GROUP BY game_id
) r ON g.game_id = r.game_id
WHERE g.is_active = 1;
GO

-- Game_requirement
CREATE OR ALTER VIEW vw_Game_Requirement_Detail AS
SELECT 
    gr.game_id,
    g.name AS game_name,
    gr.type,  -- MINIMUM hoặc RECOMMENDED
    c.name AS cpu_name,
    c.benchmark_score AS cpu_benchmark,
    gpu.name AS gpu_name,
    gpu.benchmark_score AS gpu_benchmark,
    gr.ram,
    gr.storage,
    gr.os
FROM Game_requirement gr
JOIN Games g ON gr.game_id = g.game_id
JOIN Cpus c ON gr.cpu_id = c.cpu_id
JOIN Gpus gpu ON gr.gpu_id = gpu.gpu_id;
GO


-- User_pc
CREATE OR ALTER VIEW vw_User_PC_Detail AS
SELECT 
    upc.pc_id,
    upc.user_id,
    upc.pc_name,
    c.name AS cpu_name,
    c.benchmark_score AS user_cpu_benchmark,
    gpu.name AS gpu_name,
    gpu.benchmark_score AS user_gpu_benchmark,
    upc.ram AS user_ram,
    upc.storage AS user_storage,
    upc.os AS user_os
FROM User_pc upc
JOIN Cpus c ON upc.cpu_id = c.cpu_id
JOIN Gpus gpu ON upc.gpu_id = gpu.gpu_id
WHERE ISNULL(upc.is_deleted, 0) = 0
GO

-- Reviews
CREATE OR ALTER VIEW vw_Review_Details AS
SELECT 
    r.review_id,
    r.game_id,
    g.name AS game_name,
    r.user_id,
    u.user_name,
    r.rating,
    r.comment,
    r.created_at
FROM Reviews r
JOIN Users u ON r.user_id = u.user_id
JOIN Games g ON r.game_id = g.game_id
WHERE r.is_hidden = 0 AND g.is_active = 1;
GO


