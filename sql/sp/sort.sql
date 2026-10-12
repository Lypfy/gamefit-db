CREATE OR ALTER PROCEDURE sp_sortByname 
AS
BEGIN 
    SET NOCOUNT ON;
    SELECT game_id, game_name AS name, image, trailer_url, release_date, is_active, average_rating AS rating, tags 
    FROM vw_Game_Card
    ORDER BY game_name ASC;
END 
GO

CREATE OR ALTER PROCEDURE sp_sortByRating 
AS
BEGIN
    SET NOCOUNT ON;
    SELECT game_id, game_name AS name, image, trailer_url, release_date, is_active, average_rating AS rating, tags
    FROM vw_Game_Card
    ORDER BY average_rating DESC;
END;
GO
