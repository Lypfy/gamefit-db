-- =========================================================================================
-- FILE DEMO: STORED PROCEDURE [dbo].[sp_GetWishlistStatistics]
-- THƯ MỤC: e:\Antigravity IDE\gamefit\gamefit-db\demo_script\sp\
-- MỤC ĐÍCH: KIỂM THỬ THỦ TỤC THỐNG KÊ DANH SÁCH YÊU THÍCH (WISHLIST) & MỨC ĐỘ TƯƠNG TÁC GAME
-- ĐIỂM NHẤN VẤN ĐÁP:
--   Thủ tục trả về ĐỒNG THỜI 3 BẢNG KẾT QUẢ (3 RESULT SETS) đo lường User Engagement:
--     + Bảng 1 (KPI Metrics)         : Tổng số lượt wishlist, số game được wishlist, số user dùng wishlist.
--     + Bảng 2 (Top Wishlisted Games): TOP (@limit) game được mong đợi nhất (sắp xếp theo wishlist_count DESC).
--     + Bảng 3 (Top Reviewed Games)  : TOP (@limit) game được bình luận sôi nổi nhất (review_count DESC & avg_rating DESC).
--   -> Sử dụng subquery và WHERE EXISTS trên view vw_Game_Card tối ưu hiệu năng.
-- PHỤC VỤ: CHẠY TRỰC TIẾP TRÊN SSMS & BÁO CÁO VẤN ĐÁP ĐỒ ÁN GAMEFIT
-- =========================================================================================

USE gamefit_db;
GO

PRINT N'=========================================================================================';
PRINT N'BẮT ĐẦU CHẠY DEMO SP: sp_GetWishlistStatistics';
PRINT N'=========================================================================================';
GO


-- =========================================================================================
-- KỊCH BẢN 1: GỌI VỚI THAM SỐ MẶC ĐỊNH (@limit = 10) VÀ PHÂN TÍCH 3 RESULT SETS
-- =========================================================================================
PRINT N'';
PRINT N'=========================================================================================';
PRINT N'KỊCH BẢN 1: GỌI THỦ TỤC MẶC ĐỊNH (@limit = 10) VÀ PHÂN TÍCH 3 RESULT SETS';
PRINT N'=========================================================================================';

EXEC sp_GetWishlistStatistics @limit = 10;

PRINT N'';
PRINT N'-> PHÂN TÍCH CHI TIẾT 3 RESULT SETS:';
PRINT N'   [Bảng 1]: KPI Tổng quan Wishlist:';
PRINT N'             - total_wishlist_items    : Tổng số lượt thêm game vào yêu thích.';
PRINT N'             - total_games_in_wishlist : Số lượng tựa game khác nhau có trong wishlist.';
PRINT N'             - total_users_with_wishlist: Số lượng người dùng có ít nhất 1 game trong wishlist.';
PRINT N'   [Bảng 2]: Top Wishlisted Games - Các tựa game được cộng đồng quan tâm nhất (Most Anticipated).';
PRINT N'   [Bảng 3]: Top Reviewed Games   - Các tựa game có nhiều đánh giá và điểm số cao nhất (Most Discussed).';
GO


-- =========================================================================================
-- KỊCH BẢN 2: TÙY CHỈNH GIỚI HẠN (@limit = 3)
-- Ý nghĩa: Lấy TOP 3 game hot nhất ở từng hạng mục
-- =========================================================================================
PRINT N'';
PRINT N'=========================================================================================';
PRINT N'KỊCH BẢN 2: TÙY CHỈNH LẤY TOP 3 GAME HOT NHẤT (@limit = 3)';
PRINT N'=========================================================================================';

EXEC sp_GetWishlistStatistics @limit = 3;

PRINT N'-> KẾT QUẢ 2: Cả Bảng 2 và Bảng 3 đều được giới hạn trả về chính xác 3 game đứng đầu.';
GO


-- =========================================================================================
-- KỊCH BẢN 3: KIỂM THỬ XỬ LÝ AN TOÀN KHI TRUYỀN GIÁ TRỊ BIÊN (@limit = NULL HOẶC @limit <= 0)
-- =========================================================================================
PRINT N'';
PRINT N'=========================================================================================';
PRINT N'KỊCH BẢN 3: KIỂM THỬ XỬ LÝ AN TOÀN VỚI THAM SỐ RÁC';
PRINT N'=========================================================================================';

EXEC sp_GetWishlistStatistics @limit = -1;

PRINT N'-> KẾT QUẢ 3: Thủ tục tự động gán @limit = 10 (giá trị mặc định) và thực thi an toàn.';
GO

PRINT N'=========================================================================================';
PRINT N'HOÀN TẤT DEMO SP: sp_GetWishlistStatistics';
PRINT N'=========================================================================================';
GO
