-- GPU
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

-- 1. SP THÊM GPU 
CREATE OR ALTER PROCEDURE sp_addGpus
    @gpu_id INT = NULL,
    @name NVARCHAR(100),
    @brand NVARCHAR(50),
    @benchmark_score INT = 0
AS 
BEGIN 
    SET NOCOUNT ON;
    IF @gpu_id IS NOT NULL AND @gpu_id > 0
    BEGIN
        SET IDENTITY_INSERT Gpus ON;
        INSERT INTO Gpus(gpu_id, name, brand, benchmark_score)
        VALUES (@gpu_id, @name, @brand, @benchmark_score);
        SET IDENTITY_INSERT Gpus OFF;
        SELECT gpu_id, name, brand, benchmark_score FROM Gpus WHERE gpu_id = @gpu_id;
    END
    ELSE
    BEGIN
        INSERT INTO Gpus(name, brand, benchmark_score)
        OUTPUT INSERTED.gpu_id, INSERTED.name, INSERTED.brand, INSERTED.benchmark_score
        VALUES (@name, @brand, @benchmark_score);
    END
END;
GO
-- 2. SP CẬP NHẬT GPU 
CREATE OR ALTER PROCEDURE sp_updateGpus
    @gpu_id INT,
    @name NVARCHAR(100) = NULL,
    @brand NVARCHAR(50) = NULL,
    @benchmark_score INT = NULL
AS 
BEGIN
    SET NOCOUNT ON;
    UPDATE Gpus 
    SET name = COALESCE(@name, name),
        brand = COALESCE(@brand, brand),
        benchmark_score = COALESCE(@benchmark_score, benchmark_score)
    WHERE gpu_id = @gpu_id;

    SELECT gpu_id, name, brand, benchmark_score FROM Gpus WHERE gpu_id = @gpu_id;
END;
GO

-- 3. SP DELETE GPU
CREATE OR ALTER PROCEDURE sp_deleteGpus
    @gpu_id INT 
AS 
BEGIN 
    SET NOCOUNT ON;
    DELETE FROM Gpus 
    WHERE gpu_id = @gpu_id;
END;
GO

-- 4. SP LẤY GPU THEO ID
CREATE OR ALTER PROCEDURE sp_GetGpuById
    @gpu_id INT
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT gpu_id, name, gpu_name, brand, benchmark_score 
    FROM vw_Gpu_Detail
    WHERE gpu_id = @gpu_id;
END;
GO

-- 5. SP LẤY DANH SÁCH GPU PHÂN TRANG 
CREATE OR ALTER PROCEDURE sp_GetGpusPaging
    @search NVARCHAR(100) = NULL,
    @offset INT = 0,
    @limit INT = 20
AS
BEGIN
    SET NOCOUNT ON;
    SET @search = ISNULL(@search, '');
    SELECT gpu_id, name, name AS gpu_name, brand, benchmark_score 
    FROM dbo.fn_SearchGpus(@search)
    ORDER BY gpu_id ASC
    OFFSET @offset ROWS FETCH NEXT @limit ROWS ONLY;
    SELECT COUNT(*) AS totalItems 
    FROM dbo.fn_SearchGpus(@search);
END;
GO 
    
-- 6. SP TÌM KIẾM GPU 
CREATE OR ALTER PROCEDURE sp_SearchGpusByName
    @search NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET @search = ISNULL(@search, '');
    
    SELECT gpu_id, name, gpu_name, brand, benchmark_score
    FROM vw_Gpu_Detail
    WHERE name LIKE '%' + @search + '%';
END;
GO
