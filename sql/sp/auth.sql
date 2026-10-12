CREATE OR ALTER PROCEDURE sp_AdminAddUser
    @user_name NVARCHAR(100),
    @email NVARCHAR(255),
    @password NVARCHAR(255),  -- Mật khẩu đã được mã hóa Bcrypt từ Node.js
    @role NVARCHAR(50) = N'User'
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        IF EXISTS (SELECT 1 FROM Users WHERE email = @email)
        BEGIN
            RAISERROR(N'Email này đã có người sử dụng!', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END
        IF EXISTS (SELECT 1 FROM Users WHERE user_name = @user_name)
        BEGIN
            RAISERROR(N'Tên người dùng này đã có người sử dụng!', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END
        IF @role NOT IN (N'Admin', N'User')
        BEGIN
            RAISERROR(N'Vai trò không hợp lệ! Chỉ chấp nhận Admin hoặc User.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END
        INSERT INTO Users (
            user_name,
            email,
            password,
            role,
            status,
            create_at
        )
        VALUES (
            @user_name,
            @email,
            @password,
            @role,
            N'Active',
            GETDATE()
        );
        DECLARE @new_user_id INT = SCOPE_IDENTITY();
        COMMIT TRANSACTION;
        SELECT 
            user_id,
            user_name,
            email,
            role,
            status,
            create_at
        FROM Users
        WHERE user_id = @new_user_id;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@ErrorMessage, 16, 1);
    END CATCH;
END;
GO 

--
CREATE OR ALTER PROCEDURE sp_ChangeUserRole
    @user_id INT,
    @role NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        IF NOT EXISTS (SELECT 1 FROM Users WHERE user_id = @user_id)
        BEGIN
            RAISERROR(N'Tài khoản người dùng không tồn tại!', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END
        IF @role NOT IN (N'Admin', N'User')
        BEGIN
            RAISERROR(N'Vai trò không hợp lệ! Chỉ chấp nhận Admin hoặc User.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END
        UPDATE Users
        SET role = @role
        WHERE user_id = @user_id;
        COMMIT TRANSACTION;
        SELECT 
            user_id,
            user_name,
            email,
            role,
            status
        FROM Users
        WHERE user_id = @user_id;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@ErrorMessage, 16, 1);
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE sp_LockUnlockUser
    @user_id INT,
    @status NVARCHAR(50),              
    @lock_reason NVARCHAR(255) = NULL,  
    @lock_until DATETIME = NULL        
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (
        SELECT 1
        FROM Users
        WHERE user_id = @user_id
    )
    BEGIN
        RAISERROR(N'Tài khoản người dùng không tồn tại!', 16, 1);
        RETURN;
    END

    BEGIN TRY
        BEGIN TRANSACTION;
        UPDATE Users
        SET 
            status = @status,
            lock_reason = CASE WHEN @status = 'Locked' THEN @lock_reason ELSE NULL END,
            lock_until = CASE WHEN @status = 'Locked' THEN @lock_until ELSE NULL END
        WHERE user_id = @user_id;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@ErrorMessage, 16, 1);
    END CATCH;
END;
GO

-- 1. Đăng kí tài khoản 
CREATE OR ALTER PROCEDURE sp_Register(@user_name VARCHAR(50), @email VARCHAR(100), @password VARCHAR(255))
AS
BEGIN
    IF EXISTS (
        SELECT 1 
        FROM Users
        WHERE email = @email
    )
    BEGIN
        RAISERROR(N'Email này đã có người dùng', 16, 1)
        RETURN
    END

    IF EXISTS (
        SELECT 1
        FROM Users 
        WHERE user_name = @user_name
    )
    BEGIN
        RAISERROR(N'Tên này đã có người sử dụng', 16, 1)
        RETURN
    END

    INSERT INTO Users(user_name, email, password)
    VALUES (@user_name, @email, @password)
    SELECT SCOPE_IDENTITY() AS user_id;
END
GO


-- ResetPassword 
CREATE OR ALTER PROCEDURE sp_ResetPassword(@email VARCHAR(100), @password VARCHAR(255))
AS
BEGIN
    UPDATE Users 
    SET password = @password
    WHERE email = @email
END
GO

-- 2. Cập nhật thông tin tài khoản
CREATE OR ALTER PROCEDURE sp_UpdateInformationAccount(@user_id INT, @new_user_name VARCHAR(50) = NULL, @new_email VARCHAR(100) = NULL)
AS
BEGIN
    DECLARE @user_name VARCHAR(50), @email VARCHAR(100)

    SELECT @user_name = user_name, @email = email
    FROM Users
    WHERE user_id = @user_id

    IF (@new_user_name IS NOT NULL AND EXISTS (
        SELECT 1 
        FROM Users 
        WHERE user_name = @new_user_name AND user_id != @user_id
    ))
    BEGIN
        RAISERROR(N'Tên này đã có người sử dụng', 16, 1)
        RETURN
    END

    IF (@new_email IS NOT NULL AND EXISTS (
        SELECT 1 
        FROM Users 
        WHERE email = @new_email AND user_id != @user_id
    ))
    BEGIN
        RAISERROR(N'Email này đã có người dùng', 16, 1)
        RETURN
    END

    UPDATE Users
    SET 
        user_name = ISNULL(@new_user_name, user_name),
        email = ISNULL(@new_email, email)
    WHERE user_id = @user_id
END

