-- Thêm 
CREATE OR ALTER PROCEDURE sp_AddTag
    @name NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO Tags (name, is_hidden)
    VALUES (@name, 0);

    SELECT SCOPE_IDENTITY() AS new_tag_id;
END
GO

-- Xóa
CREATE OR ALTER PROCEDURE sp_DeleteTag
    @tag_id INT
AS
BEGIN
    SET NOCOUNT ON;

    DELETE 
    FROM Tags
    WHERE tag_id = @tag_id 
END
GO

-- Cập nhật 
CREATE OR ALTER PROCEDURE sp_UpdateTag
    @tag_id INT,
    @name NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE Tags
    SET name = @name
    WHERE tag_id = @tag_id;
END
GO

