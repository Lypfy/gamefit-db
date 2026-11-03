-- =========================================================================================
-- FILE DEMO: STORED PROCEDURE [dbo].[sp_GetGenreStatistics]
-- THƯ MỤC: e:\Antigravity IDE\gamefit\gamefit-db\demo_script\sp\
-- MỤC ĐÍCH: KIỂM THỬ THỦ TỤC THỐNG KÊ CHI TIẾT THEO THỂ LOẠI GAME (GENRE INSIGHTS)
-- ĐIỂM NHẤN VẤN ĐÁP:
--   1. Trả về đồng thời 2 Result Sets:
--        + Bảng 1 (KPIs)       : Tổng số game, số thể loại đang dùng, tổng lượt wishlist.
--        + Bảng 2 (Breakdown)  : Thống kê từng thể loại: Số lượng game, số lượt wishlist,
--                                điểm đánh giá trung bình (avg_rating) và tổng số review.
--   2. Kỹ thuật CTE (Common Table Expression) WITH GameStats AS (...): Tính trước chỉ số ở mức game
--      trước khi group by thể loại, tránh lỗi nhân bản bản ghi do quan hệ N-N (Games_Tags).
--   3. Kỹ thuật CAST(rating AS FLOAT) & ROUND(..., 1): Tính điểm sao trung bình chuẩn xác có số thập phân.
--   4. Mệnh đề HAVING COUNT(gt.game_id) > 0: Tự động lọc bỏ các thể loại rác chưa có game nào.
-- PHỤC VỤ: CHẠY TRỰC TIẾP TRÊN SSMS & BÁO CÁO VẤN ĐÁP ĐỒ ÁN GAMEFIT
-- =========================================================================================

USE gamefit_db;
GO

PRINT N'=========================================================================================';
PRINT N'BẮT ĐẦU CHẠY DEMO SP: sp_GetGenreStatistics';
PRINT N'=========================================================================================';
GO


-- =========================================================================================
-- KỊCH BẢN 1: GỌI THỦ TỤC sp_GetGenreStatistics VÀ QUAN SÁT 2 BẢNG KẾT QUẢ
-- =========================================================================================
PRINT N'';
PRINT N'=========================================================================================';
PRINT N'KỊCH BẢN 1: GỌI THỦ TỤC VÀ PHÂN TÍCH 2 RESULT SETS';
PRINT N'=========================================================================================';

EXEC sp_GetGenreStatistics;

PRINT N'';
PRINT N'-> PHÂN TÍCH 2 RESULT SETS TRẢ VỀ:';
PRINT N'   [Bảng 1]: KPI Summary - total_games, total_genres, total_wishlists.';
PRINT N'   [Bảng 2]: Genre Insights Table - Danh sách thể loại kèm 4 chỉ số kinh doanh quan trọng:';
PRINT N'             - game_count    : Số lượng game thuộc thể loại đó (sắp xếp giảm dần).';
PRINT N'             - wishlist_count: Mức độ quan tâm của cộng đồng dành cho thể loại.';
PRINT N'             - avg_rating    : Điểm đánh giá trung bình từ người dùng (1 chữ số thập phân).';
PRINT N'             - review_count  : Tổng số bài đánh giá hợp lệ (is_hidden = 0).';
GO


-- =========================================================================================
-- KỊCH BẢN 2: KIỂM CHỨNG TÍNH TOÁN DỮ LIỆU CỦA CTE VÀ PHÉP LỌC HAVING
-- Ý nghĩa: Đối chiếu dữ liệu của thể loại đứng đầu với dữ liệu thực tế trong bảng Games_Tags
-- =========================================================================================
PRINT N'';
PRINT N'=========================================================================================';
PRINT N'KỊCH BẢN 2: KIỂM CHỨNG TÍNH TOÁN ĐỐI CHIẾU DỮ LIỆU THỰC TẾ';
PRINT N'=========================================================================================';

-- Lấy thể loại có nhiều game nhất
DECLARE @TopTagId INT, @TopTagName NVARCHAR(50);
SELECT TOP 1 @TopTagId = t.tag_id, @TopTagName = t.name
FROM Tags t
JOIN Games_Tags gt ON t.tag_id = gt.tag_id
GROUP BY t.tag_id, t.name
ORDER BY COUNT(gt.game_id) DESC;

PRINT N'Đối chiếu số lượng game thực tế của thể loại "' + @TopTagName + N'" (Tag ID: ' + CAST(@TopTagId AS VARCHAR(10)) + N'):';

SELECT 
    @TopTagId AS tag_id,
    @TopTagName AS genre_name,
    COUNT(gt.game_id) AS actual_game_count
FROM Games_Tags gt
WHERE gt.tag_id = @TopTagId;

PRINT N'-> KẾT QUẢ 2: Số lượng khớp hoàn toàn với kết quả trả về từ sp_GetGenreStatistics.';
GO

PRINT N'=========================================================================================';
PRINT N'HOÀN TẤT DEMO SP: sp_GetGenreStatistics';
PRINT N'=========================================================================================';
GO
