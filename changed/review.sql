-- Xóa Đánh giá (Transaction dọn sạch Votes và Reports tránh dữ liệu mồ côi)
CREATE OR ALTER PROCEDURE sp_DeleteReview
    @user_id INT,
    @game_id INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @review_id INT;
    SELECT @review_id = review_id 
    FROM Reviews 
    WHERE user_id = @user_id AND game_id = @game_id;

    IF @review_id IS NOT NULL
    BEGIN
        BEGIN TRY
            BEGIN TRANSACTION;

            -- 1. Xóa các lượt Vote của Review này (bảng Votes đa hình không có FK cascade)
            IF EXISTS (SELECT 1 FROM sys.tables WHERE name = 'Votes')
            BEGIN
                DELETE FROM Votes 
                WHERE target_type = 'REVIEW' AND target_id = @review_id;
            END;

            -- 2. Xóa các Báo cáo vi phạm của Review này
            IF EXISTS (SELECT 1 FROM sys.tables WHERE name = 'Review_Reports')
            BEGIN
                DELETE FROM Review_Reports 
                WHERE review_id = @review_id;
            END;

            -- 3. Xóa chính bản ghi Review
            DELETE FROM Reviews 
            WHERE review_id = @review_id;

            COMMIT TRANSACTION;
        END TRY
        BEGIN CATCH
            IF @@TRANCOUNT > 0
                ROLLBACK TRANSACTION;
            DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE();
            RAISERROR(@ErrMsg, 16, 1);
        END CATCH;
    END;
END;
GO