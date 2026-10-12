
-- Thêm game vào wishlist
CREATE OR ALTER PROCEDURE sp_AddGameToWishlist (@user_id INT, @game_id INT)
AS
BEGIN
    IF (@game_id IS NULL)
    BEGIN
        RAISERROR(N'Game không được trống', 16, 1)
        RETURN
    END

    IF (@user_id IS NULL)
    BEGIN
        RAISERROR(N'User không được để trống', 16, 1)
        RETURN 
    END

    IF NOT EXISTS (
        SELECT 1 
        FROM vw_Game_Card
        WHERE game_id = @game_id
    )
    BEGIN
        RAISERROR(N'Game không tồn tại trong hệ thống', 16, 1)
        RETURN
    END

    IF NOT EXISTS (
        SELECT 1 
        FROM vw_User_Safe_Profile
        WHERE user_id = @user_id
    )
    BEGIN
        RAISERROR(N'Người dùng không tồn tại trong hệ thống', 16, 1)
        RETURN 
    END

    IF EXISTS (
        SELECT 1
        FROM Wishlist
        WHERE user_id = @user_id
          AND game_id = @game_id
    )
    BEGIN
        RAISERROR(N'Game đã có trong Wishlist', 16, 1)
        RETURN
    END

    INSERT INTO Wishlist(user_id, game_id)
    VALUES (@user_id, @game_id)
END
GO 

-- Xóa game khỏi Wishlist
CREATE OR ALTER PROCEDURE sp_DeleteGameFromWishlist 
    @user_id INT,
    @game_id INT
AS
BEGIN
    DELETE 
    FROM Wishlist
    WHERE user_id = @user_id AND game_id = @game_id
END
