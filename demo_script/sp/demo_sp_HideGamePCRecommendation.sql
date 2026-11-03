-- =========================================================================================
-- FILE DEMO: STORED PROCEDURE [dbo].[sp_HideGamePCRecommendation]
-- THƯ MỤC: e:\Antigravity IDE\gamefit\gamefit-db\demo_script\sp\
-- MỤC ĐÍCH: KIỂM THỬ THỦ TỤC ẨN ĐỀ XUẤT CỦA NGƯỜI DÙNG
-- ĐIỂM NHẤN VẤN ĐÁP CỰC KỲ QUAN TRỌNG (CƠ CHẾ XÓA MỀM QUA INSTEAD OF DELETE TRIGGER):
--   1. Trong thủ tục viết: DELETE FROM Game_PC_Recommendation WHERE recommendation_id = @recommendation_id AND user_id = @user_id;
--   2. Tuy nhiên dữ liệu KHÔNG HỀ BỊ MẤT VẬT LÝ KHỎI DATABASE!
--   3. Trigger trg_GamePCRec_InsteadOfDelete đã can thiệp và biến lệnh DELETE thành:
--      UPDATE Game_PC_Recommendation SET is_hidden = 1
--   4. Đảm bảo bảo toàn toàn vẹn dữ liệu, lịch sử vote và kiểm toán của hệ thống.
--   5. Bảo mật phân quyền: Chỉ chính chủ nhân (user_id) mới có quyền ẩn bài của mình.
-- PHỤC VỤ: CHẠY TRỰC TIẾP TRÊN SSMS & BÁO CÁO VẤN ĐÁP ĐỒ ÁN GAMEFIT
-- =========================================================================================

USE gamefit_db;
GO

PRINT N'=========================================================================================';
PRINT N'BẮT ĐẦU CHẠY DEMO SP: sp_HideGamePCRecommendation';
PRINT N'=========================================================================================';
GO

-- -----------------------------------------------------------------------------------------
-- BƯỚC 0: CHUẨN BỊ DỮ LIỆU TEST (SETUP)
-- -----------------------------------------------------------------------------------------
PRINT N'-----------------------------------------------------------------------------------------';
PRINT N'BƯỚC 0: CHUẨN BỊ DỮ LIỆU TEST';
PRINT N'-----------------------------------------------------------------------------------------';

-- 1. Lấy 1 Game hợp lệ
DECLARE @GameId INT = (SELECT TOP 1 game_id FROM Games WHERE is_active = 1);

-- 2. Tạo User chính chủ (Owner)
DECLARE @OwnerId INT;
SELECT @OwnerId = user_id FROM Users WHERE email = 'owner_hide_rec@gamefit.vn';
IF @OwnerId IS NULL
BEGIN
    INSERT INTO Users (user_name, email, password, role, status)
    VALUES ('gamer_owner_hide', 'owner_hide_rec@gamefit.vn', 'hash_pass', 'User', 'Active');
    SET @OwnerId = SCOPE_IDENTITY();
END;

-- 3. Tạo User khác để test phân quyền (Attacker/Other User)
DECLARE @OtherUserId INT;
SELECT @OtherUserId = user_id FROM Users WHERE email = 'other_user_hide@gamefit.vn';
IF @OtherUserId IS NULL
BEGIN
    INSERT INTO Users (user_name, email, password, role, status)
    VALUES ('gamer_stranger', 'other_user_hide@gamefit.vn', 'hash_pass', 'User', 'Active');
    SET @OtherUserId = SCOPE_IDENTITY();
END;

-- 4. Tạo PC cho Owner
DECLARE @CpuId INT = (SELECT TOP 1 cpu_id FROM Cpus);
DECLARE @GpuId INT = (SELECT TOP 1 gpu_id FROM Gpus);
DECLARE @PcId INT;

SELECT @PcId = pc_id FROM User_pc WHERE user_id = @OwnerId AND is_deleted = 0;
IF @PcId IS NULL
BEGIN
    INSERT INTO User_pc (user_id, pc_name, cpu_id, gpu_id, ram, storage, os, is_deleted)
    VALUES (@OwnerId, N'Dàn PC Test Soft Delete Trigger', @CpuId, @GpuId, 16, 512, 'Windows 11 64-bit', 0);
    SET @PcId = SCOPE_IDENTITY();
END;

-- 5. Dọn dẹp đề xuất cũ của Owner nếu có
DELETE FROM Game_PC_Recommendation WHERE user_id = @OwnerId;

-- 6. Tạo 1 Đề xuất mới với trạng thái ban đầu is_hidden = 0
INSERT INTO Game_PC_Recommendation (user_id, game_id, pc_id, type, note, status, is_hidden, created_at)
VALUES (@OwnerId, @GameId, @PcId, 'RECOMMENDED', N'Cấu hình test tính năng ẩn/xóa mềm', 'PENDING', 0, GETDATE());

DECLARE @RecId INT = SCOPE_IDENTITY();

PRINT N'-> Đã khởi tạo dữ liệu mẫu thành công:';
PRINT N'   + Game ID          : ' + CAST(@GameId AS VARCHAR(10));
PRINT N'   + Owner ID         : ' + CAST(@OwnerId AS VARCHAR(10)) + N' (gamer_owner_hide)';
PRINT N'   + Stranger ID      : ' + CAST(@OtherUserId AS VARCHAR(10)) + N' (gamer_stranger)';
PRINT N'   + Recommendation ID: ' + CAST(@RecId AS VARCHAR(10));
PRINT N'   + Trạng thái ban đầu: is_hidden = 0';
GO


-- =========================================================================================
-- KỊCH BẢN 1: BẢO MẬT PHÂN QUYỀN - NGƯỜI KHÁC KHÔNG THỂ ẨN ĐỀ XUẤT CỦA CHỦ SỞ HỮU
-- Ý nghĩa: Kiểm tra điều kiện AND user_id = @user_id trong thủ tục
-- =========================================================================================
PRINT N'';
PRINT N'=========================================================================================';
PRINT N'KỊCH BẢN 1: USER KHÁC CỐ TÌNH GỌI ẨN BÀI CỦA NGƯỜI KHÁC';
PRINT N'=========================================================================================';

DECLARE @OwnerId INT = (SELECT user_id FROM Users WHERE email = 'owner_hide_rec@gamefit.vn');
DECLARE @OtherUserId INT = (SELECT user_id FROM Users WHERE email = 'other_user_hide@gamefit.vn');
DECLARE @RecId INT = (SELECT TOP 1 recommendation_id FROM Game_PC_Recommendation WHERE user_id = @OwnerId);

PRINT N'Stranger (ID = ' + CAST(@OtherUserId AS VARCHAR(10)) + N') cố tình ẩn bài Rec ID = ' + CAST(@RecId AS VARCHAR(10)) + N'...';
EXEC sp_HideGamePCRecommendation 
    @user_id = @OtherUserId, 
    @recommendation_id = @RecId;

-- Kiểm tra lại: is_hidden vẫn phải là 0
SELECT recommendation_id, user_id, is_hidden, note
FROM Game_PC_Recommendation
WHERE recommendation_id = @RecId;

PRINT N'-> KẾT QUẢ 1: An toàn! Bản ghi vẫn giữ nguyên is_hidden = 0 vì user_id không khớp.';
GO


-- =========================================================================================
-- KỊCH BẢN 2: CHÍNH CHỦ ẨN ĐỀ XUẤT & KIỂM CHỨNG CƠ CHẾ XÓA MỀM (INSTEAD OF DELETE TRIGGER)
-- Ý nghĩa & Trọng tâm vấn đáp:
--   - Gọi sp_HideGamePCRecommendation thực thi DELETE.
--   - Nhưng SELECT kiểm tra lại: BẢN GHI VẪN CÒN, CHỈ CÓ is_hidden ĐƯỢC CHUYỂN TỪ 0 THÀNH 1!
-- =========================================================================================
PRINT N'';
PRINT N'=========================================================================================';
PRINT N'KỊCH BẢN 2: CHÍNH CHỦ ẨN ĐỀ XUẤT VÀ KIỂM CHỨNG TRIGGER XÓA MỀM';
PRINT N'=========================================================================================';

DECLARE @OwnerId INT = (SELECT user_id FROM Users WHERE email = 'owner_hide_rec@gamefit.vn');
DECLARE @RecId INT = (SELECT TOP 1 recommendation_id FROM Game_PC_Recommendation WHERE user_id = @OwnerId);

PRINT N'[2.1] Trước khi gọi sp_HideGamePCRecommendation:';
SELECT recommendation_id, user_id, is_hidden, status, note
FROM Game_PC_Recommendation
WHERE recommendation_id = @RecId;

-- Chính chủ gọi ẩn đề xuất
PRINT N'';
PRINT N'-> Chính chủ gọi EXEC sp_HideGamePCRecommendation @user_id = ' + CAST(@OwnerId AS VARCHAR(10)) + N', @recommendation_id = ' + CAST(@RecId AS VARCHAR(10));
EXEC sp_HideGamePCRecommendation 
    @user_id = @OwnerId, 
    @recommendation_id = @RecId;

PRINT N'';
PRINT N'[2.2] Sau khi gọi sp_HideGamePCRecommendation (Kiểm chứng trigger):';
SELECT recommendation_id, user_id, is_hidden, status, note
FROM Game_PC_Recommendation
WHERE recommendation_id = @RecId;

PRINT N'';
PRINT N'-> KẾT QUẢ 2:';
PRINT N'   + Bản ghi KHÔNG hề bị xóa mất khỏi bảng Game_PC_Recommendation.';
PRINT N'   + Cột is_hidden đã được cập nhật thành 1 nhờ Trigger trg_GamePCRec_InsteadOfDelete!';
PRINT N'   + Các câu truy vấn danh sách hiển thị ngoài trang chủ (WHERE is_hidden = 0) sẽ tự động không hiển thị bài này nữa.';
GO


-- -----------------------------------------------------------------------------------------
-- BƯỚC CLEANUP: DỌN DẸP DỮ LIỆU TEST
-- -----------------------------------------------------------------------------------------
PRINT N'';
PRINT N'-----------------------------------------------------------------------------------------';
PRINT N'DỌN DẸP DỮ LIỆU TEST (CLEANUP)';
PRINT N'-----------------------------------------------------------------------------------------';

-- Lưu ý: Vì bảng có trigger INSTEAD OF DELETE, để xóa cứng dữ liệu dọn dẹp ta có thể tạm tắt trigger hoặc giữ nguyên
DECLARE @OwnerId INT = (SELECT user_id FROM Users WHERE email = 'owner_hide_rec@gamefit.vn');
DECLARE @OtherUserId INT = (SELECT user_id FROM Users WHERE email = 'other_user_hide@gamefit.vn');

IF @OwnerId IS NOT NULL
BEGIN
    -- Vô hiệu hóa tạm thời trigger để xóa dọn dẹp sạch sẽ
    ALTER TABLE Game_PC_Recommendation DISABLE TRIGGER trg_GamePCRec_InsteadOfDelete;
    DELETE FROM Game_PC_Recommendation WHERE user_id = @OwnerId;
    ALTER TABLE Game_PC_Recommendation ENABLE TRIGGER trg_GamePCRec_InsteadOfDelete;

    DELETE FROM User_pc WHERE user_id = @OwnerId;
    DELETE FROM Users WHERE user_id IN (@OwnerId, @OtherUserId);
END;

PRINT N'-> Đã dọn dẹp sạch sẽ dữ liệu test trong Game_PC_Recommendation, User_pc và Users.';
GO

PRINT N'=========================================================================================';
PRINT N'HOÀN TẤT DEMO SP: sp_HideGamePCRecommendation';
PRINT N'=========================================================================================';
GO
