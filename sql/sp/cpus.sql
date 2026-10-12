-- CPU 

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

-- 1. SP THÊM CPU 
CREATE OR ALTER PROCEDURE sp_addCpus
    @cpu_id INT = NULL,
    @name NVARCHAR(100),
    @brand NVARCHAR(50),
    @benchmark_score INT = 0
AS 
BEGIN 
    SET NOCOUNT ON;
    IF @cpu_id IS NOT NULL AND @cpu_id > 0
    BEGIN
        SET IDENTITY_INSERT Cpus ON;
        INSERT INTO Cpus(cpu_id, name, brand, benchmark_score)
        VALUES (@cpu_id, @name, @brand, @benchmark_score);
        SET IDENTITY_INSERT Cpus OFF;
        
        SELECT cpu_id, name, brand, benchmark_score FROM Cpus WHERE cpu_id = @cpu_id;
    END
    ELSE
    BEGIN
        INSERT INTO Cpus(name, brand, benchmark_score)
        OUTPUT INSERTED.cpu_id, INSERTED.name, INSERTED.brand, INSERTED.benchmark_score
        VALUES (@name, @brand, @benchmark_score);
    END
END;
GO

-- 2. SP XÓA CPU
CREATE OR ALTER PROCEDURE sp_deleteCpus
    @cpu_id INT
AS 
BEGIN 
    SET NOCOUNT ON;
    DELETE FROM Cpus 
    WHERE cpu_id = @cpu_id;
END;
GO

-- 3. SP LẤY CPU THEO ID 
CREATE OR ALTER PROCEDURE sp_GetCpuById
    @cpu_id INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * 
    FROM vw_Cpu_Detail
    WHERE cpu_id = @cpu_id;
END;
GO

-- 4. SP LẤY DS CPU PHÂN TRANG 
CREATE OR ALTER PROCEDURE sp_GetCpusPaging
    @search NVARCHAR(100) = NULL,
    @offset INT = 0,
    @limit INT = 20
AS
BEGIN
    SET NOCOUNT ON;
    SET @search = ISNULL(@search, '');
    
    SELECT * 
    FROM vw_Cpu_Detail
    WHERE name LIKE '%' + @search + '%'
    ORDER BY cpu_id ASC
    OFFSET @offset ROWS 
    FETCH NEXT @limit ROWS ONLY;
    
    SELECT COUNT(*) AS totalItems 
    FROM vw_Cpu_Detail
    WHERE name LIKE '%' + @search + '%';
END;
GO

-- 5. SP TÌM KIẾM CPU 
CREATE OR ALTER PROCEDURE sp_SearchCpusByName
    @search NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET @search = ISNULL(@search, '');
    
    SELECT * 
    FROM vw_Cpu_Detail
    WHERE name LIKE '%' + @search + '%';
END;
GO
--
GO

-- 6. SP CẬP NHẬT CPU
CREATE OR ALTER PROCEDURE sp_updateCpus
    @cpu_id INT,
    @name NVARCHAR(100) = NULL,
    @brand NVARCHAR(50) = NULL,
    @benchmark_score INT = NULL
AS 
BEGIN
    SET NOCOUNT ON;
    UPDATE Cpus
    SET name = COALESCE(@name, name),
        brand = COALESCE(@brand, brand),
        benchmark_score = COALESCE(@benchmark_score, benchmark_score)
    WHERE cpu_id = @cpu_id;

    SELECT cpu_id, name, brand, benchmark_score FROM Cpus WHERE cpu_id = @cpu_id;
END;
GO