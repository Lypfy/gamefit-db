-- =========================================================================================
-- FILE DEMO VẤN ĐÁP TỔNG HỢP: BỘ 4 THỦ TỤC THỐNG KÊ DASHBOARD ADMIN (ANALYTICS SUITE)
-- THƯ MỤC: e:\Antigravity IDE\gamefit\gamefit-db\demo_script\sp\
-- BỘ 4 STORED PROCEDURES ĐƯỢC KẾT NỐI TRONG TOÀN BỘ PHÂN HỆ BÁO CÁO ADMIN:
--   1. sp_GetGeneralStatistics  : Thống kê tổng quan số lượng game, trạng thái & biểu đồ 7 năm
--   2. sp_GetGenreStatistics    : Thống kê chi tiết thể loại (Game count, Wishlist, Avg rating, Reviews)
--   3. sp_GetHardwareStatistics : Thống kê phần cứng kiểu Steam Survey (CPU, GPU, RAM Tier)
--   4. sp_GetWishlistStatistics : Thống kê tương tác người dùng (Wishlist KPIs, Top Game mong đợi, Top Review)
-- PHỤC VỤ: CHẠY TRỰC TIẾP TRÊN SSMS & BÁO CÁO VẤN ĐÁP ĐỒ ÁN GAMEFIT
-- =========================================================================================

USE gamefit_db;
GO

PRINT N'=========================================================================================';
PRINT N'BẮT ĐẦU CHẠY DEMO TỔNG HỢP: BỘ 4 THỦ TỤC THỐNG KÊ DASHBOARD ADMIN';
PRINT N'=========================================================================================';
GO


-- =========================================================================================
-- PHẦN 1: THỐNG KÊ TỔNG QUAN HỆ THỐNG (sp_GetGeneralStatistics)
-- Mục đích: Nạp dữ liệu cho trang chủ Dashboard (KPIs, Biểu đồ phát triển, Danh sách game mới)
-- =========================================================================================
PRINT N'';
PRINT N'=========================================================================================';
PRINT N'PHẦN 1: THỰC THI sp_GetGeneralStatistics (THỐNG KÊ TỔNG QUAN GAME)';
PRINT N'=========================================================================================';

EXEC sp_GetGeneralStatistics @limit = 10;

PRINT N'-> KẾT QUẢ PHẦN 1: Cung cấp đầy đủ 4 bảng dữ liệu cho trang chủ Admin Dashboard.';
GO


-- =========================================================================================
-- PHẦN 2: THỐNG KÊ THỂ LOẠI GAME (sp_GetGenreStatistics)
-- Mục đích: Nạp dữ liệu cho tab "Phân tích thể loại" (Độ phổ biến, Điểm đánh giá theo thể loại)
-- =========================================================================================
PRINT N'';
PRINT N'=========================================================================================';
PRINT N'PHẦN 2: THỰC THI sp_GetGenreStatistics (PHÂN TÍCH THỂ LOẠI QUA CTE)';
PRINT N'=========================================================================================';

EXEC sp_GetGenreStatistics;

PRINT N'-> KẾT QUẢ PHẦN 2: Cung cấp 2 bảng dữ liệu: Tổng quan thể loại & Chi tiết từng thể loại.';
GO


-- =========================================================================================
-- PHẦN 3: THỐNG KÊ PHẦN CỨNG & MÁY TÍNH GAME THỦ (sp_GetHardwareStatistics)
-- Mục đích: Nạp dữ liệu cho tab "Phân tích phần cứng" (Mô phỏng Steam Hardware Survey)
-- =========================================================================================
PRINT N'';
PRINT N'=========================================================================================';
PRINT N'PHẦN 3: THỰC THI sp_GetHardwareStatistics (STEAM-LIKE HARDWARE SURVEY)';
PRINT N'=========================================================================================';

EXEC sp_GetHardwareStatistics @limit = 5;

PRINT N'-> KẾT QUẢ PHẦN 3: Cung cấp đầy đủ 6 bảng dữ liệu (KPI, Thị phần CPU, Thị phần GPU, Top CPU, Top GPU, Phân bố RAM).';
GO


-- =========================================================================================
-- PHẦN 4: THỐNG KÊ DANH SÁCH YÊU THÍCH & TƯƠNG TÁC (sp_GetWishlistStatistics)
-- Mục đích: Nạp dữ liệu cho tab "Mức độ quan tâm cộng đồng" (Game được yêu thích & bàn luận nhiều nhất)
-- =========================================================================================
PRINT N'';
PRINT N'=========================================================================================';
PRINT N'PHẦN 4: THỰC THI sp_GetWishlistStatistics (USER ENGAGEMENT & WISHLIST)';
PRINT N'=========================================================================================';

EXEC sp_GetWishlistStatistics @limit = 5;

PRINT N'-> KẾT QUẢ PHẦN 4: Cung cấp 3 bảng dữ liệu: KPI Wishlist, Top game được mong đợi nhất, Top game được đánh giá nhiều nhất.';
GO

PRINT N'=========================================================================================';
PRINT N'HOÀN TẤT DEMO TOÀN BỘ PHÂN HỆ THỐNG KÊ ADMIN (ADMIN DASHBOARD ANALYTICS SUITE)';
PRINT N'=========================================================================================';
GO
