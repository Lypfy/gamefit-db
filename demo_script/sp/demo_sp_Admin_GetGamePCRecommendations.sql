-- =========================================================================================
-- FILE DEMO: STORED PROCEDURE [dbo].[sp_Admin_GetGamePCRecommendations]
-- THƯ MỤC: e:\Antigravity IDE\gamefit\gamefit-db\demo_script\sp\
-- MỤC ĐÍCH: KIỂM THỬ THỦ TỤC LẤY DANH SÁCH ĐỀ XUẤT CẤU HÌNH PC DÀNH CHO ADMIN KIỂM DUYỆT
-- ĐIỂM NHẤN: 
--   1. Phân loại theo status (PENDING, APPROVED, REJECTED) & type (MINIMUM, RECOMMENDED)
--   2. Lọc theo ngưỡng điểm vote thực tế (net_votes = upvotes - downvotes >= @min_votes)
--   3. Sắp xếp ưu tiên: PENDING lên đầu, tiếp đến là bài có điểm Net Vote cao nhất
-- PHỤC VỤ: CHẠY TRỰC TIẾP TRÊN SSMS & BÁO CÁO VẤN ĐÁP ĐỒ ÁN GAMEFIT
-- =========================================================================================

USE gamefit_db;
GO

PRINT N'=========================================================================================';
PRINT N'BẮT ĐẦU CHẠY DEMO SP: sp_Admin_GetGamePCRecommendations';
PRINT N'=========================================================================================';
GO

-- -----------------------------------------------------------------------------------------
-- BƯỚC 0: CHUẨN BỊ DỮ LIỆU TEST (SETUP)
-- -----------------------------------------------------------------------------------------
PRINT N'-----------------------------------------------------------------------------------------';
PRINT N'BƯỚC 0: CHUẨN BỊ DỮ LIỆU TEST (USER, PC, ĐỀ XUẤT & ĐIỂM VOTE)';
PRINT N'-----------------------------------------------------------------------------------------';

-- 1. Lấy Game hợp lệ đang hoạt động
DECLARE @GameId INT = (SELECT TOP 1 game_id FROM Games WHERE is_active = 1);

-- 2. Tạo User người chơi đề xuất cấu hình (Submitter)
DECLARE @SubmitterId INT;
SELECT @SubmitterId = user_id FROM Users WHERE email = 'submitter_pc_rec@gamefit.vn';
IF @SubmitterId IS NULL
BEGIN
    INSERT INTO Users (user_name, email, password, role, status)
    VALUES ('gamer_pro_build', 'submitter_pc_rec@gamefit.vn', 'hash_pass', 'User', 'Active');
    SET @SubmitterId = SCOPE_IDENTITY();
END;

-- 3. Tạo User thành viên cộng đồng bình chọn (Voter)
DECLARE @VoterId INT;
SELECT @VoterId = user_id FROM Users WHERE email = 'voter_pc_rec@gamefit.vn';
IF @VoterId IS NULL
BEGIN
    INSERT INTO Users (user_name, email, password, role, status)
    VALUES ('gamer_voter', 'voter_pc_rec@gamefit.vn', 'hash_pass', 'User', 'Active');
    SET @VoterId = SCOPE_IDENTITY();
END;

-- 4. Tạo hoặc lấy cấu hình PC của Submitter trong bảng User_pc
DECLARE @CpuId INT = (SELECT TOP 1 cpu_id FROM Cpus);
DECLARE @GpuId INT = (SELECT TOP 1 gpu_id FROM Gpus);
DECLARE @PcId INT;

SELECT @PcId = pc_id FROM User_pc WHERE user_id = @SubmitterId AND is_deleted = 0;
IF @PcId IS NULL
BEGIN
    INSERT INTO User_pc (user_id, pc_name, cpu_id, gpu_id, ram, storage, os, is_deleted)
    VALUES (@SubmitterId, N'Dàn PC Gaming Test Admin Rec', @CpuId, @GpuId, 16, 512, 'Windows 11 64-bit', 0);
    SET @PcId = SCOPE_IDENTITY();
END;

-- 5. Dọn dẹp đề xuất cũ của User này cho Game này nếu có
DELETE FROM Votes WHERE target_type = 'RECOMMENDATION' AND target_id IN (
    SELECT recommendation_id FROM Game_PC_Recommendation WHERE user_id = @SubmitterId AND game_id = @GameId
);
DELETE FROM Game_PC_Recommendation WHERE user_id = @SubmitterId AND game_id = @GameId;

-- 6. Tạo 1 Đề xuất mới: type = 'RECOMMENDED', status = 'PENDING', is_hidden = 0
INSERT INTO Game_PC_Recommendation (user_id, game_id, pc_id, type, note, status, is_hidden, created_at)
VALUES (@SubmitterId, @GameId, @PcId, 'RECOMMENDED', N'Cấu hình chiến game siêu mượt 1080p Ultra setting 75+ FPS', 'PENDING', 0, GETDATE());

DECLARE @RecId INT = SCOPE_IDENTITY();

-- 7. Thêm lượt UPVOTE (+1) trong bảng Votes để bài đề xuất có điểm net_votes = 1 (thỏa mãn @min_votes = 1)
INSERT INTO Votes (user_id, target_type, target_id, vote_type, created_at)
VALUES (@VoterId, 'RECOMMENDATION', @RecId, 1, GETDATE());

PRINT N'-> Đã khởi tạo dữ liệu mẫu thành công:';
PRINT N'   + Game ID          : ' + CAST(@GameId AS VARCHAR(10));
PRINT N'   + Submitter ID     : ' + CAST(@SubmitterId AS VARCHAR(10)) + N' (gamer_pro_build)';
PRINT N'   + PC ID            : ' + CAST(@PcId AS VARCHAR(10)) + N' (Dàn PC Gaming Test Admin Rec)';
PRINT N'   + Recommendation ID: ' + CAST(@RecId AS VARCHAR(10)) + N' (Trạng thái: PENDING, Type: RECOMMENDED)';
PRINT N'   + Điểm Vote        : 1 Upvote (Net Votes = 1)';
GO


-- =========================================================================================
-- KỊCH BẢN 1: ADMIN LẤY DANH SÁCH ĐỀ XUẤT CHỜ DUYỆT (MẶC ĐỊNH: @status = 'PENDING', @min_votes = 1)
-- Ý nghĩa: Đây là màn hình mặc định khi Admin mở tab "Kiểm duyệt đề xuất cấu hình"
-- Thuật toán sắp xếp: Ưu tiên PENDING lên đầu, sau đó xếp theo điểm Net Votes cao nhất
-- =========================================================================================
PRINT N'';
PRINT N'=========================================================================================';
PRINT N'KỊCH BẢN 1: ADMIN LẤY DANH SÁCH ĐỀ XUẤT ĐANG CHỜ DUYỆT (@status = ''PENDING'')';
PRINT N'=========================================================================================';

EXEC sp_Admin_GetGamePCRecommendations 
    @status = 'PENDING', 
    @type = NULL, 
    @search = NULL, 
    @min_votes = 1;

PRINT N'-> KẾT QUẢ 1: Trả về đầy đủ thông tin đề xuất kèm linh kiện chi tiết (CPU, GPU, Benchmark, RAM, Storage, OS) và điểm Vote cộng đồng.';
GO


-- =========================================================================================
-- KỊCH BẢN 2: LỌC THEO LOẠI CẤU HÌNH (@type = 'RECOMMENDED' HOẶC 'MINIMUM')
-- Ý nghĩa: Admin chỉ muốn lọc các cấu hình đề nghị chơi mượt (RECOMMENDED)
-- =========================================================================================
PRINT N'';
PRINT N'=========================================================================================';
PRINT N'KỊCH BẢN 2: LỌC THEO LOẠI ĐỀ XUẤT (@type = ''RECOMMENDED'')';
PRINT N'=========================================================================================';

EXEC sp_Admin_GetGamePCRecommendations 
    @status = 'PENDING', 
    @type = 'RECOMMENDED', 
    @search = NULL, 
    @min_votes = 1;

PRINT N'-> KẾT QUẢ 2: Chỉ hiển thị các bài đề xuất có type là RECOMMENDED.';
GO


-- =========================================================================================
-- KỊCH BẢN 3: LỌC THEO NGƯỠNG ĐIỂM VOTE TỐI THIỂU (@min_votes = 5)
-- Ý nghĩa: Chỉ xem các cấu hình được cộng đồng tín nhiệm cao (ít nhất 5 upvote ròng)
-- =========================================================================================
PRINT N'';
PRINT N'=========================================================================================';
PRINT N'KỊCH BẢN 3: LỌC VỚI NGƯỠNG ĐIỂM VOTE CAO (@min_votes = 5)';
PRINT N'=========================================================================================';

-- Đề xuất test của chúng ta mới có net_votes = 1, do đó với min_votes = 5 sẽ được lọc bỏ
EXEC sp_Admin_GetGamePCRecommendations 
    @status = 'PENDING', 
    @type = NULL, 
    @search = NULL, 
    @min_votes = 5;

PRINT N'-> KẾT QUẢ 3: Đề xuất có điểm vote = 1 đã được loại trừ chính xác theo điều kiện net_votes >= 5.';
GO


-- =========================================================================================
-- KỊCH BẢN 4: TÌM KIẾM THEO TỪ KHÓA (@search = N'Test Admin Rec')
-- Ý nghĩa: Tìm kiếm theo tên máy PC, tên game hoặc tên người đề xuất
-- =========================================================================================
PRINT N'';
PRINT N'=========================================================================================';
PRINT N'KỊCH BẢN 4: TÌM KIẾM THEO TÊN CẤU HÌNH MÁY PC (@search = N''Test Admin Rec'')';
PRINT N'=========================================================================================';

EXEC sp_Admin_GetGamePCRecommendations 
    @status = NULL, 
    @type = NULL, 
    @search = N'Test Admin Rec', 
    @min_votes = 1;

PRINT N'-> KẾT QUẢ 4: Tìm kiếm thành công theo tên cấu hình máy PC.';
GO


-- -----------------------------------------------------------------------------------------
-- BƯỚC CLEANUP: DỌN DẸP DỮ LIỆU TEST
-- -----------------------------------------------------------------------------------------
PRINT N'';
PRINT N'-----------------------------------------------------------------------------------------';
PRINT N'DỌN DẸP DỮ LIỆU TEST (CLEANUP)';
PRINT N'-----------------------------------------------------------------------------------------';

DECLARE @SubmitterId INT = (SELECT user_id FROM Users WHERE email = 'submitter_pc_rec@gamefit.vn');
DECLARE @VoterId INT = (SELECT user_id FROM Users WHERE email = 'voter_pc_rec@gamefit.vn');

IF @SubmitterId IS NOT NULL
BEGIN
    DELETE FROM Votes WHERE target_type = 'RECOMMENDATION' AND target_id IN (
        SELECT recommendation_id FROM Game_PC_Recommendation WHERE user_id = @SubmitterId
    );
    DELETE FROM Game_PC_Recommendation WHERE user_id = @SubmitterId;
    DELETE FROM User_pc WHERE user_id = @SubmitterId;
    DELETE FROM Users WHERE user_id IN (@SubmitterId, @VoterId);
END;

PRINT N'-> Đã dọn dẹp sạch sẽ dữ liệu test trong Votes, Game_PC_Recommendation, User_pc và Users.';
GO

PRINT N'=========================================================================================';
PRINT N'HOÀN TẤT DEMO SP: sp_Admin_GetGamePCRecommendations';
PRINT N'=========================================================================================';
GO
