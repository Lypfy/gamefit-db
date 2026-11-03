-- =========================================================================================
-- FILE DEMO: STORED PROCEDURE [dbo].[sp_GetHardwareStatistics]
-- THƯ MỤC: e:\Antigravity IDE\gamefit\gamefit-db\demo_script\sp\
-- MỤC ĐÍCH: KIỂM THỬ THỦ TỤC THỐNG KÊ PHẦN CỨNG HỆ THỐNG & CẤU HÌNH NGƯỜI DÙNG (HARDWARE INSIGHTS)
-- ĐIỂM NHẤN VẤN ĐÁP:
--   Thủ tục mô phỏng báo cáo phần cứng chuyên sâu tương tự STEAM HARDWARE SURVEY,
--   trả về ĐỒNG THỜI 6 BẢNG KẾT QUẢ (6 RESULT SETS):
--     + Bảng 1 (KPI Metrics)         : Tổng số lượng CPU, GPU trong kho và số lượng máy User PC đang dùng.
--     + Bảng 2 (CPU Market Share)    : Thị phần thương hiệu CPU (Intel, AMD...).
--     + Bảng 3 (GPU Market Share)    : Thị phần thương hiệu GPU (NVIDIA, AMD, Intel, Apple, Khác) qua CASE WHEN LIKE.
--     + Bảng 4 (Top CPUs In Rigs)    : TOP (@limit) CPU được game thủ cấu hình nhiều nhất kèm điểm Benchmark.
--     + Bảng 5 (Top GPUs In Rigs)    : TOP (@limit) GPU được game thủ cấu hình nhiều nhất kèm điểm Benchmark.
--     + Bảng 6 (RAM Distribution)    : Tỷ lệ phân bố các bậc RAM (<=8GB, 12GB, 16GB, 32GB, >32GB) qua CASE WHEN.
--   -> Luôn lọc loại trừ máy đã xóa mềm: WHERE ISNULL(up.is_deleted, 0) = 0.
-- PHỤC VỤ: CHẠY TRỰC TIẾP TRÊN SSMS & BÁO CÁO VẤN ĐÁP ĐỒ ÁN GAMEFIT
-- =========================================================================================

USE gamefit_db;
GO

PRINT N'=========================================================================================';
PRINT N'BẮT ĐẦU CHẠY DEMO SP: sp_GetHardwareStatistics';
PRINT N'=========================================================================================';
GO


-- =========================================================================================
-- KỊCH BẢN 1: GỌI VỚI THAM SỐ MẶC ĐỊNH (@limit = 20) VÀ PHÂN TÍCH 6 RESULT SETS
-- Ý nghĩa: Toàn bộ dashboard phân tích phần cứng được nạp dữ liệu đầy đủ chỉ trong 1 lần gọi SP
-- =========================================================================================
PRINT N'';
PRINT N'=========================================================================================';
PRINT N'KỊCH BẢN 1: GỌI VỚI THAM SỐ MẶC ĐỊNH (@limit = 20) VÀ PHÂN TÍCH 6 BẢNG DỮ LIỆU';
PRINT N'=========================================================================================';

EXEC sp_GetHardwareStatistics @limit = 20;

PRINT N'';
PRINT N'-> PHÂN TÍCH CHI TIẾT 6 RESULT SETS:';
PRINT N'   [Bảng 1]: KPI Tổng quan (total_cpus, total_gpus, total_user_pcs).';
PRINT N'   [Bảng 2]: Pie Chart CPU - Thị phần hãng CPU.';
PRINT N'   [Bảng 3]: Pie Chart GPU - Thị phần hãng GPU (chuẩn hóa về NVIDIA, AMD, Intel, Apple, Other).';
PRINT N'   [Bảng 4]: Bar Chart Top CPU - Danh sách CPU phổ biến nhất trong các dàn máy của game thủ.';
PRINT N'   [Bảng 5]: Bar Chart Top GPU - Danh sách GPU phổ biến nhất trong các dàn máy của game thủ.';
PRINT N'   [Bảng 6]: Tier Chart RAM - Phân bổ mức dung lượng RAM (<= 8GB, 12GB, 16GB, 32GB, > 32GB).';
GO


-- =========================================================================================
-- KỊCH BẢN 2: TÙY CHỈNH GIỚI HẠN HIỂN THỊ TOP LINH KIỆN (@limit = 5)
-- Ý nghĩa: Chỉ lấy TOP 5 CPU và TOP 5 GPU phổ biến nhất
-- =========================================================================================
PRINT N'';
PRINT N'=========================================================================================';
PRINT N'KỊCH BẢN 2: LẤY TOP 5 LINH KIỆN (@limit = 5)';
PRINT N'=========================================================================================';

EXEC sp_GetHardwareStatistics @limit = 5;

PRINT N'-> KẾT QUẢ 2: Bảng 4 và Bảng 5 đã giới hạn chính xác TOP 5 linh kiện được dùng nhiều nhất.';
GO


-- =========================================================================================
-- KỊCH BẢN 3: KIỂM THỬ GIÁ TRỊ BIÊN / XỬ LÝ AN TOÀN (@limit = NULL HOẶC @limit <= 0)
-- =========================================================================================
PRINT N'';
PRINT N'=========================================================================================';
PRINT N'KỊCH BẢN 3: KIỂM THỬ XỬ LÝ AN TOÀN KHI TRUYỀN @limit = NULL HOẶC SỐ ÂM';
PRINT N'=========================================================================================';

EXEC sp_GetHardwareStatistics @limit = NULL;

PRINT N'-> KẾT QUẢ 3: Thủ tục tự động fallback về @limit = 20 an toàn.';
GO

PRINT N'=========================================================================================';
PRINT N'HOÀN TẤT DEMO SP: sp_GetHardwareStatistics';
PRINT N'=========================================================================================';
GO
