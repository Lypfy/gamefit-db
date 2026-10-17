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

-- Xóa cấu hình máy cá nhân (Transaction đồng bộ ẩn đề xuất Game_PC_Recommendation và xóa User_pc)
CREATE OR ALTER PROCEDURE sp_DeleteComputerConfig 
    @pc_id INT,
    @user_id INT
AS
BEGIN 
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NOT EXISTS (
        SELECT 1 
        FROM User_pc 
        WHERE pc_id = @pc_id AND user_id = @user_id
    )
    BEGIN
        RAISERROR(N'Cấu hình máy không tồn tại hoặc bạn không có quyền xóa.', 16, 1);
        RETURN;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- 1. Tự động ẩn tất cả các bài đề xuất cấu hình (Game_PC_Recommendation) sử dụng dàn máy này
        IF EXISTS (SELECT 1 FROM sys.tables WHERE name = 'Game_PC_Recommendation')
        BEGIN
            UPDATE Game_PC_Recommendation
            SET is_hidden = 1
            WHERE pc_id = @pc_id AND user_id = @user_id;
        END;

        -- 2. Xóa cấu hình máy (trigger trg_UserPC_InsteadOfDelete sẽ cập nhật is_deleted = 1)
        DELETE FROM User_pc
        WHERE pc_id = @pc_id AND user_id = @user_id;

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

