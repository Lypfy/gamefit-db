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

