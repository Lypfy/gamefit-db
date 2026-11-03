-- =========================================================================================
-- FILE DEMO: STORED PROCEDURE [dbo].[sp_GetGeneralStatistics]
-- THƯ MỤC: e:\Antigravity IDE\gamefit\gamefit-db\demo_script\sp\
-- MỤC ĐÍCH: KIỂM THỬ THỦ TỤC THỐNG KÊ TỔNG QUAN HỆ THỐNG GAME DÀNH CHO DASHBOARD ADMIN
-- ĐIỂM NHẤN VẤN ĐÁP:
--   Thủ tục trả về ĐỒNG THỜI 4 BẢNG KẾT QUẢ (4 RESULT SETS) phục vụ giao diện Admin:
--     + Bảng 1 (KPI Counters)     : Tổng số game, số game đang hoạt động và ngừng hoạt động.
--     + Bảng 2 (Trend Line Chart) : Biến động số lượng game phát hành theo 7 năm gần nhất.
--     + Bảng 3 (Donut Chart)      : Tỷ lệ phân bố trạng thái game (Đang hoạt động VS Ngừng hoạt động).
--     + Bảng 4 (Data Table)       : Danh sách TOP (@limit) game mới nhất vừa được thêm vào hệ thống.
-- PHỤC VỤ: CHẠY TRỰC TIẾP TRÊN SSMS & BÁO CÁO VẤN ĐÁP ĐỒ ÁN GAMEFIT
-- =========================================================================================

USE gamefit_db;
GO

PRINT N'=========================================================================================';
PRINT N'BẮT ĐẦU CHẠY DEMO SP: sp_GetGeneralStatistics';
PRINT N'=========================================================================================';
GO


-- =========================================================================================
-- KỊCH BẢN 1: GỌI THỦ TỤC VỚI THAM SỐ MẶC ĐỊNH (@limit = 20)
-- Ý nghĩa: Đây là lệnh gọi tiêu chuẩn khi Admin vừa đăng nhập và vào trang Dashboard tổng quan
-- =========================================================================================
PRINT N'';
PRINT N'=========================================================================================';
PRINT N'KỊCH BẢN 1: GỌI VỚI GIÁ TRỊ MẶC ĐỊNH (@limit = 20) VÀ PHÂN TÍCH 4 RESULT SETS';
PRINT N'=========================================================================================';

EXEC sp_GetGeneralStatistics @limit = 20;

PRINT N'';
PRINT N'-> PHÂN TÍCH 4 RESULT SETS TRẢ VỀ:';
PRINT N'   [Bảng 1]: KPI Cards - Thống kê tổng số lượng game (total_games, active_games, inactive_games).';
PRINT N'   [Bảng 2]: Line Chart - Số lượng game theo từng năm (7 năm gần nhất) phục vụ vẽ biểu đồ phát triển.';
PRINT N'   [Bảng 3]: Donut Chart - Tỷ lệ % game hoạt động vs ngừng hoạt động (dùng UNION ALL).';
PRINT N'   [Bảng 4]: Recent Games Table - Lấy 20 game mới nhất qua view vw_Game_Card.';
GO


-- =========================================================================================
-- KỊCH BẢN 2: TÙY CHỈNH GIỚI HẠN HIỂN THỊ (@limit = 5)
-- Ý nghĩa: Admin chỉ muốn widget bảng game hiển thị nhanh 5 game mới nhất để không chiếm diện tích
-- =========================================================================================
PRINT N'';
PRINT N'=========================================================================================';
PRINT N'KỊCH BẢN 2: TÙY BIẾN THAM SỐ LIMIT (@limit = 5)';
PRINT N'=========================================================================================';

EXEC sp_GetGeneralStatistics @limit = 5;

PRINT N'-> KẾT QUẢ 2: Bảng 4 đã giới hạn chính xác hiển thị đúng 5 game mới nhất.';
GO


-- =========================================================================================
-- KỊCH BẢN 3: KIỂM THỬ XỬ LÝ GIÁ TRỊ BIÊN / THAM SỐ RÁC (@limit = NULL HOẶC @limit <= 0)
-- Ý nghĩa: Đảm bảo độ bền vững (robustness), SP tự động fallback về giá trị an toàn (@limit = 20)
-- =========================================================================================
PRINT N'';
PRINT N'=========================================================================================';
PRINT N'KỊCH BẢN 3: TRUYỀN THAM SỐ KHÔNG HỢP LỆ (@limit = NULL HOẶC -10)';
PRINT N'=========================================================================================';

PRINT N'[3.1] Gọi với @limit = NULL:';
EXEC sp_GetGeneralStatistics @limit = NULL;

PRINT N'[3.2] Gọi với @limit = -10 (Số âm):';
EXEC sp_GetGeneralStatistics @limit = -10;

PRINT N'-> KẾT QUẢ 3: Thủ tục kiểm tra IF @limit IS NULL OR @limit <= 0 SET @limit = 20 nên luôn chạy an toàn!';
GO

PRINT N'=========================================================================================';
PRINT N'HOÀN TẤT DEMO SP: sp_GetGeneralStatistics';
PRINT N'=========================================================================================';
GO
