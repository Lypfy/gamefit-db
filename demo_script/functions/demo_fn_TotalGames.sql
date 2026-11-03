-- =========================================================================================
-- FILE DEMO VẤN ĐÁP: FUNCTION [dbo].[fn_TotalGames]
-- MỤC ĐÍCH: HÀM TÍNH TỔNG SỐ GAME THEO BỘ LỌC ĐA TIÊU CHÍ (PHỤC VỤ PHÂN TRANG)
-- LOẠI HÀM: SCALAR-VALUED FUNCTION (HÀM VÔ HƯỚNG, TRẢ VỀ KIỂU INT)
-- =========================================================================================

USE gamefit_db;
GO

PRINT N'=========================================================================================';
PRINT N'BẮT ĐẦU CHẠY DEMO HÀM: dbo.fn_TotalGames';
PRINT N'=========================================================================================';
GO

-- =========================================================================================
-- PHẦN 1: CODE FUNCTION ĐỂ HỌC THUỘC (NẾU GIẢNG VIÊN YÊU CẦU VIẾT LẠI)
-- =========================================================================================
/*
CREATE OR ALTER FUNCTION dbo.fn_TotalGames(
    @categories NVARCHAR(MAX) = NULL, -- Danh sách thể loại (ngăn cách bằng dấu phẩy)
    @publishers NVARCHAR(MAX) = NULL, -- Danh sách nhà phát hành
    @rams NVARCHAR(MAX) = NULL        -- Danh sách mức RAM tối thiểu (4, 8, 16...)
)
RETURNS INT
AS
BEGIN
    DECLARE @total INT;
    SELECT @total = COUNT(DISTINCT g.game_id)
    FROM Games g
    WHERE 
        g.is_active = 1 
        AND (@publishers IS NULL OR @publishers = '' OR g.publisher IN (SELECT TRIM(value) FROM STRING_SPLIT(@publishers, ',')))
        AND (@categories IS NULL OR @categories = '' OR EXISTS (
            SELECT 1 FROM Games_Tags gt2
            JOIN Tags t2 ON gt2.tag_id = t2.tag_id
            WHERE gt2.game_id = g.game_id
              AND t2.name IN (SELECT TRIM(value) FROM STRING_SPLIT(@categories, ','))
              AND t2.is_hidden = 0
        ))
        AND (@rams IS NULL OR @rams = '' OR EXISTS (
            SELECT 1 FROM Game_requirement gr
            WHERE gr.game_id = g.game_id 
              AND gr.type = 'MINIMUM'
              AND gr.ram IN (SELECT TRIM(value) FROM STRING_SPLIT(@rams, ','))
        ));
    RETURN @total;
END;
GO
*/


-- =========================================================================================
-- KỊCH BẢN 1: KHÔNG TRUYỀN BỘ LỌC (LẤY TỔNG SỐ GAME ĐANG HOẠT ĐỘNG TOÀN HỆ THỐNG)
-- Ý nghĩa: Khi người dùng mới vào trang web, chưa chọn lọc bất kỳ tiêu chí nào.
-- =========================================================================================
PRINT N'-----------------------------------------------------------------------------------------';
PRINT N'KỊCH BẢN 1: KHÔNG TRUYỀN LỌC (LẤY TOÀN BỘ GAME ACTIVE)';
PRINT N'-----------------------------------------------------------------------------------------';

-- Cách gọi hàm
SELECT dbo.fn_TotalGames(NULL, NULL, NULL) AS [Tong_Game_Theo_Ham];

-- Đối chiếu kiểm chứng bằng câu lệnh COUNT trực tiếp từ bảng Games
SELECT COUNT(*) AS [Tong_Game_Doi_Chieu] 
FROM Games 
WHERE is_active = 1;

PRINT N'-> KẾT QUẢ 1: Số lượng trả về từ hàm khớp chính xác 100% với CSDL.';
GO


-- =========================================================================================
-- KỊCH BẢN 2: LỌC THEO 1 TIÊU CHÍ (VÍ DỤ: LỌC THEO THỂ LOẠI 'Action')
-- =========================================================================================
PRINT N'';
PRINT N'-----------------------------------------------------------------------------------------';
PRINT N'KỊCH BẢN 2: LỌC THEO 1 THỂ LOẠI (N''Action'')';
PRINT N'-----------------------------------------------------------------------------------------';

-- 1. Gọi hàm
SELECT dbo.fn_TotalGames(N'Action', NULL, NULL) AS [So_Game_The_Loai_Action];

-- 2. Đối chiếu kiểm chứng bằng SELECT trực tiếp
SELECT COUNT(DISTINCT g.game_id) AS [So_Game_Action_Doi_Chieu]
FROM Games g
JOIN Games_Tags gt ON g.game_id = gt.game_id
JOIN Tags t ON gt.tag_id = t.tag_id
WHERE g.is_active = 1 
  AND t.is_hidden = 0 
  AND t.name = N'Action';
GO


-- =========================================================================================
-- KỊCH BẢN 3: LỌC KẾT HỢP NHIỀU TIÊU CHÍ (ĐA THỂ LOẠI + MỨC RAM)
-- Ví dụ: Tìm game thuộc thể loại 'Action' HOẶC 'Adventure' VÀ có RAM tối thiểu là '8' hoặc '16' GB
-- =========================================================================================
PRINT N'';
PRINT N'-----------------------------------------------------------------------------------------';
PRINT N'KỊCH BẢN 3: LỌC KẾT HỢP ĐA TIÊU CHÍ (Thể loại: Action, Adventure & RAM: 8, 16)';
PRINT N'-----------------------------------------------------------------------------------------';

DECLARE @Cat NVARCHAR(100) = N'Action, Adventure';
DECLARE @Ram NVARCHAR(50)  = N'8, 16';

-- 1. Gọi hàm
SELECT dbo.fn_TotalGames(@Cat, NULL, @Ram) AS [So_Game_Thoa_Dieu_Kien];

-- 2. Xem danh sách các game thỏa mãn thực tế
SELECT DISTINCT g.game_id, g.name AS GameName, gr.ram AS Ram_Toi_Thieu
FROM Games g
JOIN Games_Tags gt ON g.game_id = gt.game_id
JOIN Tags t ON gt.tag_id = t.tag_id
JOIN Game_requirement gr ON g.game_id = gr.game_id AND gr.type = 'MINIMUM'
WHERE g.is_active = 1 
  AND t.is_hidden = 0
  AND t.name IN (N'Action', N'Adventure')
  AND gr.ram IN (8, 16);
GO


-- =========================================================================================
-- KỊCH BẢN 4: TRƯỜNG HỢP KHÔNG TÌM THẤY (KẾT QUẢ = 0)
-- Ý nghĩa: Kiểm tra tính an toàn của hàm khi người dùng tìm kiếm từ khóa/tiêu chí ảo không tồn tại.
-- =========================================================================================
PRINT N'';
PRINT N'-----------------------------------------------------------------------------------------';
PRINT N'KỊCH BẢN 4: TRUYỀN TIÊU CHÍ ẢO KHÔNG TỒN TẠI (KẾT QUẢ PHẢI BẰNG 0)';
PRINT N'-----------------------------------------------------------------------------------------';

-- Gọi hàm với thể loại và nhà phát hành không có thật
SELECT dbo.fn_TotalGames(N'TheLoaiAo_XYZ_999', N'NhaPhatHanhKhongTonTai', NULL) AS [Ket_Qua_Tim_Kiem];
PRINT N'-> Hàm trả về đúng 0, không bị lỗi cú pháp hay văng lỗi runtime.';
GO


-- =========================================================================================
-- KỊCH BẢN 5: ỨNG DỤNG THỰC TẾ TRONG HỆ THỐNG (TÍNH TỔNG SỐ TRANG PHÂN TRANG - PAGINATION)
-- Ý nghĩa: Backend dùng hàm này để tính xem có bao nhiêu trang (VD: mỗi trang 12 game)
-- =========================================================================================
PRINT N'';
PRINT N'-----------------------------------------------------------------------------------------';
PRINT N'KỊCH BẢN 5: ỨNG DỤNG TÍNH SỐ TRANG (PAGINATION) TRÊN GIAO DIỆN WEB';
PRINT N'-----------------------------------------------------------------------------------------';

DECLARE @PageSize INT = 12; -- Mỗi trang hiển thị 12 game
DECLARE @TotalGames INT = dbo.fn_TotalGames(NULL, NULL, NULL);
DECLARE @TotalPages INT = CEILING(CAST(@TotalGames AS FLOAT) / @PageSize);

SELECT 
    @TotalGames AS [Tong_So_Game],
    @PageSize   AS [So_Game_Moi_Trang],
    @TotalPages AS [Tong_So_Trang_Hien_Thi];

PRINT N'=========================================================================================';
PRINT N'HOÀN TẤT DEMO FUNCTION dbo.fn_TotalGames!';
PRINT N'=========================================================================================';
GO
