-- =========================================================================================
-- FILE DEMO: STORED PROCEDURE [dbo].[sp_Admin_RejectRecommendation]
-- THƯ MỤC: e:\Antigravity IDE\gamefit\gamefit-db\demo_script\sp\
-- MỤC ĐÍCH: KIỂM THỬ THỦ TỤC ADMIN TỪ CHỐI ĐỀ XUẤT CẤU HÌNH PC & TỰ ĐỘNG BẮN THÔNG BÁO
-- ĐIỂM NHẤN VẤN ĐÁP:
--   1. Sử dụng Transaction & SET XACT_ABORT ON đảm bảo tính toàn vẹn ACID.
--   2. Cập nhật status = 'REJECTED', reviewed_by, reviewed_at, reject_reason.
--   3. Tự động sinh Notification gửi cho người đề xuất kèm lý do cụ thể và link trỏ về game.
--   4. Khi status chuyển sang 'REJECTED', thủ tục sp_GetGamePCRecommendations sẽ tự động ẩn bài
--      khỏi trang chi tiết game (nhờ điều kiện AND ISNULL(gpr.status, 'PENDING') <> 'REJECTED').
-- PHỤC VỤ: CHẠY TRỰC TIẾP TRÊN SSMS & BÁO CÁO VẤN ĐÁP ĐỒ ÁN GAMEFIT
-- =========================================================================================

USE gamefit_db;
GO

PRINT N'=========================================================================================';
PRINT N'BẮT ĐẦU CHẠY DEMO SP: sp_Admin_RejectRecommendation';
PRINT N'=========================================================================================';
GO

-- -----------------------------------------------------------------------------------------
-- BƯỚC 0: CHUẨN BỊ DỮ LIỆU TEST (SETUP)
-- -----------------------------------------------------------------------------------------
PRINT N'-----------------------------------------------------------------------------------------';
PRINT N'BƯỚC 0: CHUẨN BỊ DỮ LIỆU TEST (USER ĐỀ XUẤT, ADMIN, PC & ĐỀ XUẤT)';
PRINT N'-----------------------------------------------------------------------------------------';

-- 1. Lấy 1 Game hợp lệ
DECLARE @GameId INT = (SELECT TOP 1 game_id FROM Games WHERE is_active = 1);

-- 2. Tạo User người chơi đề xuất cấu hình (Submitter)
DECLARE @SubmitterId INT;
SELECT @SubmitterId = user_id FROM Users WHERE email = 'submitter_reject_rec@gamefit.vn';
IF @SubmitterId IS NULL
BEGIN
    INSERT INTO Users (user_name, email, password, role, status)
    VALUES ('gamer_to_reject', 'submitter_reject_rec@gamefit.vn', 'hash_pass', 'User', 'Active');
    SET @SubmitterId = SCOPE_IDENTITY();
END;

-- 3. Tạo User Quản trị viên (Admin Reviewer)
DECLARE @AdminId INT;
SELECT @AdminId = user_id FROM Users WHERE email = 'admin_reviewer_rec@gamefit.vn';
IF @AdminId IS NULL
BEGIN
    INSERT INTO Users (user_name, email, password, role, status)
    VALUES ('admin_hardware_mod', 'admin_reviewer_rec@gamefit.vn', 'hash_pass', 'Admin', 'Active');
    SET @AdminId = SCOPE_IDENTITY();
END;

-- 4. Tạo PC cho Submitter
DECLARE @CpuId INT = (SELECT TOP 1 cpu_id FROM Cpus);
DECLARE @GpuId INT = (SELECT TOP 1 gpu_id FROM Gpus);
DECLARE @PcId INT;

SELECT @PcId = pc_id FROM User_pc WHERE user_id = @SubmitterId AND is_deleted = 0;
IF @PcId IS NULL
BEGIN
    INSERT INTO User_pc (user_id, pc_name, cpu_id, gpu_id, ram, storage, os, is_deleted)
    VALUES (@SubmitterId, N'PC Test Reject Logic', @CpuId, @GpuId, 8, 256, 'Windows 10 64-bit', 0);
    SET @PcId = SCOPE_IDENTITY();
END;

-- 5. Dọn dẹp dữ liệu cũ nếu có
DELETE FROM Notifications WHERE user_id = @SubmitterId;
DELETE FROM Game_PC_Recommendation WHERE user_id = @SubmitterId;

-- 6. Tạo 1 Đề xuất cấu hình đang ở trạng thái PENDING
INSERT INTO Game_PC_Recommendation (user_id, game_id, pc_id, type, note, status, is_hidden, created_at)
VALUES (@SubmitterId, @GameId, @PcId, 'RECOMMENDED', N'Cấu hình đề xuất chơi game mượt 60 FPS', 'PENDING', 0, GETDATE());

DECLARE @RecId INT = SCOPE_IDENTITY();

PRINT N'-> Đã khởi tạo dữ liệu mẫu thành công:';
PRINT N'   + Game ID          : ' + CAST(@GameId AS VARCHAR(10));
PRINT N'   + Submitter ID     : ' + CAST(@SubmitterId AS VARCHAR(10)) + N' (gamer_to_reject)';
PRINT N'   + Admin ID         : ' + CAST(@AdminId AS VARCHAR(10)) + N' (admin_hardware_mod)';
PRINT N'   + Recommendation ID: ' + CAST(@RecId AS VARCHAR(10)) + N' (status = PENDING)';
GO


-- =========================================================================================
-- KỊCH BẢN 1: ADMIN TỪ CHỐI ĐỀ XUẤT THÀNH CÔNG (HAPPY PATH)
-- Ý nghĩa: Admin đối chiếu benchmark thấy linh kiện quá yếu không đủ đáp ứng nên từ chối
-- kèm theo lý do cụ thể, hệ thống tự động bắn Notification giải thích cho game thủ
-- =========================================================================================
PRINT N'';
PRINT N'=========================================================================================';
PRINT N'KỊCH BẢN 1: ADMIN TỪ CHỐI ĐỀ XUẤT VÀ GỬI THÔNG BÁO TỰ ĐỘNG';
PRINT N'=========================================================================================';

DECLARE @SubmitterId INT = (SELECT user_id FROM Users WHERE email = 'submitter_reject_rec@gamefit.vn');
DECLARE @AdminId INT = (SELECT user_id FROM Users WHERE email = 'admin_reviewer_rec@gamefit.vn');
DECLARE @RecId INT = (SELECT TOP 1 recommendation_id FROM Game_PC_Recommendation WHERE user_id = @SubmitterId);

PRINT N'[Trước khi từ chối]:';
SELECT recommendation_id, user_id, game_id, status, reviewed_by, reviewed_at, reject_reason
FROM Game_PC_Recommendation
WHERE recommendation_id = @RecId;

-- Thực hiện từ chối
PRINT N'-> Admin gọi EXEC sp_Admin_RejectRecommendation...';
EXEC sp_Admin_RejectRecommendation 
    @recommendation_id = @RecId, 
    @admin_id = @AdminId, 
    @reject_reason = N'Card đồ họa (GPU) và RAM 8GB không đủ đáp ứng mức thiết lập RECOMMENDED của tựa game này.';

PRINT N'[Sau khi từ chối - Bảng Game_PC_Recommendation]:';
SELECT recommendation_id, user_id, game_id, status, reviewed_by, reviewed_at, reject_reason
FROM Game_PC_Recommendation
WHERE recommendation_id = @RecId;

PRINT N'[Kiểm tra bảng Notifications của người đề xuất]:';
SELECT notification_id, user_id, title, message, type, target_url, created_at
FROM Notifications
WHERE user_id = @SubmitterId
ORDER BY created_at DESC;

PRINT N'-> KẾT QUẢ 1:';
PRINT N'   + status đã chuyển sang REJECTED.';
PRINT N'   + reviewed_by = ' + CAST(@AdminId AS VARCHAR(10)) + N', reviewed_at và reject_reason đã được ghi nhận.';
PRINT N'   + Bảng Notifications tự động phát sinh 1 thông báo giải thích lý do cho người dùng.';
GO


-- =========================================================================================
-- KỊCH BẢN 2: VALIDATION - BẮT LỖI KHI ĐỀ XUẤT KHÔNG TỒN TẠI (ID ẢO = 999999)
-- Ý nghĩa: Kiểm tra ràng buộc tồn tại bản ghi đề xuất
-- =========================================================================================
PRINT N'';
PRINT N'=========================================================================================';
PRINT N'KỊCH BẢN 2: BẮT LỖI KHI ĐỀ XUẤT KHÔNG TỒN TẠI';
PRINT N'=========================================================================================';

DECLARE @AdminId INT = (SELECT user_id FROM Users WHERE email = 'admin_reviewer_rec@gamefit.vn');

BEGIN TRY
    PRINT N'Cố tình từ chối Recommendation ID = 999999...';
    EXEC sp_Admin_RejectRecommendation 
        @recommendation_id = 999999, 
        @admin_id = @AdminId, 
        @reject_reason = N'Lý do ảo';

    PRINT N'LỖI TEST: Không được phép chạy thành công!';
END TRY
BEGIN CATCH
    PRINT N'-> KẾT QUẢ 2 (Bắt lỗi chuẩn): ' + ERROR_MESSAGE();
END CATCH;
GO


-- -----------------------------------------------------------------------------------------
-- BƯỚC CLEANUP: DỌN DẸP DỮ LIỆU TEST
-- -----------------------------------------------------------------------------------------
PRINT N'';
PRINT N'-----------------------------------------------------------------------------------------';
PRINT N'DỌN DẸP DỮ LIỆU TEST (CLEANUP)';
PRINT N'-----------------------------------------------------------------------------------------';

DECLARE @SubmitterId INT = (SELECT user_id FROM Users WHERE email = 'submitter_reject_rec@gamefit.vn');
DECLARE @AdminId INT = (SELECT user_id FROM Users WHERE email = 'admin_reviewer_rec@gamefit.vn');

IF @SubmitterId IS NOT NULL
BEGIN
    DELETE FROM Notifications WHERE user_id = @SubmitterId;
    DELETE FROM Game_PC_Recommendation WHERE user_id = @SubmitterId;
    DELETE FROM User_pc WHERE user_id = @SubmitterId;
    DELETE FROM Users WHERE user_id IN (@SubmitterId, @AdminId);
END;

PRINT N'-> Đã dọn dẹp sạch sẽ dữ liệu test trong Notifications, Game_PC_Recommendation, User_pc và Users.';
GO

PRINT N'=========================================================================================';
PRINT N'HOÀN TẤT DEMO SP: sp_Admin_RejectRecommendation';
PRINT N'=========================================================================================';
GO
