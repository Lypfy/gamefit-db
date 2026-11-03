-- =========================================================================================
-- FILE DEMO: STORED PROCEDURE [dbo].[sp_Admin_GetRecommendationDetail]
-- THƯ MỤC: e:\Antigravity IDE\gamefit\gamefit-db\demo_script\sp\
-- MỤC ĐÍCH: KIỂM THỬ THỦ TỤC LẤY CHI TIẾT ĐỀ XUẤT ĐỂ SO SÁNH CẤU HÌNH VỚI GAME (MODAL ADMIN)
-- ĐIỂM NHẤN VẤN ĐÁP: 
--   Thủ tục trả về ĐỒNG THỜI 2 BẢNG KẾT QUẢ (2 RESULT SETS):
--     + Bảng 1: Thông số dàn PC của User (CPU, GPU, Benchmark, RAM, Storage, Vote...)
--     + Bảng 2: Cấu hình chuẩn của Game từ vw_Game_Requirement_Detail (MINIMUM & RECOMMENDED)
--   -> Giúp Admin đối chiếu trực quan 1-1 trên giao diện trước khi quyết định Duyệt / Từ chối.
-- PHỤC VỤ: CHẠY TRỰC TIẾP TRÊN SSMS & BÁO CÁO VẤN ĐÁP ĐỒ ÁN GAMEFIT
-- =========================================================================================

USE gamefit_db;
GO

PRINT N'=========================================================================================';
PRINT N'BẮT ĐẦU CHẠY DEMO SP: sp_Admin_GetRecommendationDetail';
PRINT N'=========================================================================================';
GO

-- -----------------------------------------------------------------------------------------
-- BƯỚC 0: CHUẨN BỊ DỮ LIỆU TEST (SETUP)
-- -----------------------------------------------------------------------------------------
PRINT N'-----------------------------------------------------------------------------------------';
PRINT N'BƯỚC 0: CHUẨN BỊ DỮ LIỆU TEST (USER, PC, ĐỀ XUẤT CẤU HÌNH)';
PRINT N'-----------------------------------------------------------------------------------------';

-- 1. Lấy Game hợp lệ có cấu hình trong Game_requirement
DECLARE @GameId INT;
SELECT TOP 1 @GameId = gr.game_id 
FROM Game_requirement gr
JOIN Games g ON gr.game_id = g.game_id
WHERE g.is_active = 1;

-- 2. Tạo User người đề xuất (Submitter)
DECLARE @SubmitterId INT;
SELECT @SubmitterId = user_id FROM Users WHERE email = 'submitter_detail_rec@gamefit.vn';
IF @SubmitterId IS NULL
BEGIN
    INSERT INTO Users (user_name, email, password, role, status)
    VALUES ('gamer_detail_test', 'submitter_detail_rec@gamefit.vn', 'hash_pass', 'User', 'Active');
    SET @SubmitterId = SCOPE_IDENTITY();
END;

-- 3. Tạo PC cho Submitter
DECLARE @CpuId INT = (SELECT TOP 1 cpu_id FROM Cpus);
DECLARE @GpuId INT = (SELECT TOP 1 gpu_id FROM Gpus);
DECLARE @PcId INT;

SELECT @PcId = pc_id FROM User_pc WHERE user_id = @SubmitterId AND is_deleted = 0;
IF @PcId IS NULL
BEGIN
    INSERT INTO User_pc (user_id, pc_name, cpu_id, gpu_id, ram, storage, os, is_deleted)
    VALUES (@SubmitterId, N'PC Gaming Detail Compare Test', @CpuId, @GpuId, 16, 1000, 'Windows 11 64-bit', 0);
    SET @PcId = SCOPE_IDENTITY();
END;

-- 4. Dọn dẹp đề xuất cũ của User này
DELETE FROM Votes WHERE target_type = 'RECOMMENDATION' AND target_id IN (
    SELECT recommendation_id FROM Game_PC_Recommendation WHERE user_id = @SubmitterId
);
DELETE FROM Game_PC_Recommendation WHERE user_id = @SubmitterId;

-- 5. Tạo 1 Đề xuất mới
INSERT INTO Game_PC_Recommendation (user_id, game_id, pc_id, type, note, status, is_hidden, created_at)
VALUES (@SubmitterId, @GameId, @PcId, 'RECOMMENDED', N'Cấu hình đề xuất chơi mượt mà ở độ phân giải 2K', 'PENDING', 0, GETDATE());

DECLARE @RecId INT = SCOPE_IDENTITY();

-- 6. Thêm lượt vote
INSERT INTO Votes (user_id, target_type, target_id, vote_type, created_at)
VALUES (@SubmitterId, 'RECOMMENDATION', @RecId, 1, GETDATE());

PRINT N'-> Đã khởi tạo dữ liệu mẫu thành công:';
PRINT N'   + Game ID          : ' + CAST(@GameId AS VARCHAR(10));
PRINT N'   + Submitter ID     : ' + CAST(@SubmitterId AS VARCHAR(10));
PRINT N'   + PC ID            : ' + CAST(@PcId AS VARCHAR(10));
PRINT N'   + Recommendation ID: ' + CAST(@RecId AS VARCHAR(10));
GO


-- =========================================================================================
-- KỊCH BẢN 1: GỌI sp_Admin_GetRecommendationDetail VỚI ID HỢP LỆ (HAPPY PATH)
-- Quan sát: Hệ thống sẽ trả về 2 Result Sets:
--   - Result Set 1: Cấu hình của máy người dùng đề xuất kèm Benchmark & Vote
--   - Result Set 2: Cấu hình chuẩn của Game từ vw_Game_Requirement_Detail
-- =========================================================================================
PRINT N'';
PRINT N'=========================================================================================';
PRINT N'KỊCH BẢN 1: GỌI THỦ TỤC VÀ QUAN SÁT 2 BẢNG KẾT QUẢ ĐỐI CHIẾU CẤU HÌNH';
PRINT N'=========================================================================================';

DECLARE @SubmitterId INT = (SELECT user_id FROM Users WHERE email = 'submitter_detail_rec@gamefit.vn');
DECLARE @RecId INT = (SELECT TOP 1 recommendation_id FROM Game_PC_Recommendation WHERE user_id = @SubmitterId);

PRINT N'Thực thi: EXEC sp_Admin_GetRecommendationDetail @recommendation_id = ' + CAST(@RecId AS VARCHAR(10));
EXEC sp_Admin_GetRecommendationDetail @recommendation_id = @RecId;

PRINT N'';
PRINT N'-> KẾT QUẢ 1:';
PRINT N'   + Bảng 1: Cung cấp chi tiết linh kiện máy người dùng, điểm Benchmark CPU/GPU và điểm Vote.';
PRINT N'   + Bảng 2: Cung cấp cấu hình chuẩn hiện tại của Game (MINIMUM và RECOMMENDED) để Admin đối chiếu.';
GO


-- =========================================================================================
-- KỊCH BẢN 2: GỌI VỚI ID ĐỀ XUẤT ẢO HOẶC KHÔNG TỒN TẠI (ID = 999999)
-- Ý nghĩa: Kiểm tra tính an toàn, cả 2 bảng trả về 0 dòng mà không gây lỗi cú pháp/hệ thống
-- =========================================================================================
PRINT N'';
PRINT N'=========================================================================================';
PRINT N'KỊCH BẢN 2: GỌI VỚI ID ẢO (999999)';
PRINT N'=========================================================================================';

EXEC sp_Admin_GetRecommendationDetail @recommendation_id = 999999;

PRINT N'-> KẾT QUẢ 2: Cả 2 bảng kết quả đều trả về 0 dòng an toàn.';
GO


-- -----------------------------------------------------------------------------------------
-- BƯỚC CLEANUP: DỌN DẸP DỮ LIỆU TEST
-- -----------------------------------------------------------------------------------------
PRINT N'';
PRINT N'-----------------------------------------------------------------------------------------';
PRINT N'DỌN DẸP DỮ LIỆU TEST (CLEANUP)';
PRINT N'-----------------------------------------------------------------------------------------';

DECLARE @SubmitterId INT = (SELECT user_id FROM Users WHERE email = 'submitter_detail_rec@gamefit.vn');

IF @SubmitterId IS NOT NULL
BEGIN
    DELETE FROM Votes WHERE target_type = 'RECOMMENDATION' AND target_id IN (
        SELECT recommendation_id FROM Game_PC_Recommendation WHERE user_id = @SubmitterId
    );
    DELETE FROM Game_PC_Recommendation WHERE user_id = @SubmitterId;
    DELETE FROM User_pc WHERE user_id = @SubmitterId;
    DELETE FROM Users WHERE user_id = @SubmitterId;
END;

PRINT N'-> Đã dọn dẹp sạch sẽ dữ liệu test.';
GO

PRINT N'=========================================================================================';
PRINT N'HOÀN TẤT DEMO SP: sp_Admin_GetRecommendationDetail';
PRINT N'=========================================================================================';
GO
