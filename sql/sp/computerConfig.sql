-- Lưu thông tin cấu hình máy
CREATE OR ALTER PROCEDURE sp_AddComputerConfig 
    @pc_name NVARCHAR(255), 
    @user_id INT, 
    @cpu_id INT, 
    @gpu_id INT, 
    @os VARCHAR(50), 
    @ram INT, 
    @storage INT
AS
BEGIN
    IF (@pc_name IS NULL)
    BEGIN
        RAISERROR(N'Tên máy tính không được để trống', 16, 1)
        RETURN 
    END

    IF (@cpu_id IS NULL)
    BEGIN
        RAISERROR(N'Cpu không được để trống', 16, 1)
        RETURN
    END

    IF (@gpu_id IS NULL)
    BEGIN
        RAISERROR(N'Gpu không được để trống', 16, 1)
        RETURN
    END

    IF (@ram IS NULL)
    BEGIN
        RAISERROR(N'Ram không được để trống', 16, 1)
        RETURN
    END

    IF (@ram <= 0)
    BEGIN
        RAISERROR(N'Giá trị RAM không được âm', 16, 1)
        RETURN 
    END

    IF (@storage <=0)
    BEGIN
        RAISERROR(N'Dung lượng bộ nhớ không được âm', 16, 1)
        RETURN
    END

    INSERT INTO User_pc (pc_name, user_id, cpu_id, gpu_id, os, ram, storage)
    VALUES(@pc_name, @user_id, @cpu_id, @gpu_id, @os, @ram, @storage)
    SELECT SCOPE_IDENTITY() AS pc_id
END
GO

-- Sửa cấu hình máy
CREATE OR ALTER PROCEDURE sp_UpdateComputerConfig 
    @pc_id INT,
    @pc_name NVARCHAR(255), 
    @user_id INT, 
    @cpu_id INT, 
    @gpu_id INT, 
    @os VARCHAR(50), 
    @ram INT, 
    @storage INT
AS
BEGIN
    UPDATE User_pc
    SET pc_name = @pc_name,
        cpu_id = @cpu_id,
        gpu_id = @gpu_id,
        os = @os,
        ram = @ram,
        storage = @storage
    WHERE user_id = @user_id AND pc_id = @pc_id
END
GO 

-- Xóa cấu hình máy cá nhân
CREATE OR ALTER  PROCEDURE sp_DeleteComputerConfig 
    @pc_id INT,
    @user_id INT
AS
BEGIN 
    DELETE 
    FROM User_pc
    WHERE pc_id = @pc_id AND user_id = @user_id
END
GO 

