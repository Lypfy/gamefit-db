SELECT dbo.fn_TotalGames(N'Action', NULL, NULL) AS [Tong_Game_Action];

SELECT COUNT(DISTINCT g.game_id) 
FROM Games g
JOIN Games_Tags gt ON gt.game_id = g.game_id
JOIN Tags t on gt.tag_id = t.tag_id
WHERE g.is_active = 1 AND t.is_hidden = 0 AND t.name = N'Action';