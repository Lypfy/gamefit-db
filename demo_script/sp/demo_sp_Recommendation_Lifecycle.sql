-- =========================================================================================
-- FILE DEMO VẤN ĐÁP TỔNG HỢP: QUY TRÌNH ĐỀ XUẤT CẤU HÌNH & KIỂM DUYỆT (RECOMMENDATION LIFECYCLE)
-- THƯ MỤC: e:\Antigravity IDE\gamefit\gamefit-db\demo_script\sp\
-- BỘ 4 STORED PROCEDURES ĐƯỢC KẾT NỐI TRONG LUỒNG NGHIỆP VỤ THỰC TẾ:
--   1. sp_Admin_GetGamePCRecommendations : Lấy danh sách đề xuất chờ duyệt (lọc status, type, vote >= 1)
--   2. sp_Admin_GetRecommendationDetail  : Đối chiếu 2 bảng: Máy đề xuất VS Cấu hình chuẩn của Game
--   3. sp_Admin_RejectRecommendation     : Admin từ chối kèm lý do + Tự động gửi Notification cho user
--   4. sp_HideGamePCRecommendation       : User ẩn đề xuất (Cơ chế Xóa Mềm qua INSTEAD OF DELETE trigger)
-- PHỤC VỤ: CHẠY TRỰC TIẾP TRÊN SSMS & BÁO CÁO VẤN ĐÁP ĐỒ ÁN GAMEFIT
-- =========================================================================================

USE gamefit_db;
GO

PRINT N'=========================================================================================';
PRINT N'BẮT ĐẦU CHẠY DEMO QUY TRÌNH VÒNG ĐỜI ĐỀ XUẤT CẤU HÌNH PC (RECOMMENDATION LIFECYCLE)';
PRINT N'=========================================================================================';
GO

-- -----------------------------------------------------------------------------------------
-- BƯỚC 0: CHUẨN BỊ MÔI TRƯỜNG & DỮ LIỆU TEST (SETUP)
-- -----------------------------------------------------------------------------------------
PRINT N'-----------------------------------------------------------------------------------------';
PRINT N'BƯỚC 0: KHỞI TẠO TÀI KHOẢN, GAME & DÀN PC CỦA GAME THỦ';
PRINT N'-----------------------------------------------------------------------------------------';

-- 1. Lấy Game hợp lệ có cấu hình trong Game_requirement
DECLARE @GameId INT;
SELECT TOP 1 @GameId = gr.game_id 
FROM Game_requirement gr
JOIN Games g ON gr.game_id = g.game_id
WHERE g.is_active = 1;

-- 2. Tạo User người đề xuất (Submitter)
DECLARE @SubmitterId INT;
SELECT @SubmitterId = user_id FROM Users WHERE email = 'submitter_flow@gamefit.vn';
IF @SubmitterId IS NULL
BEGIN
    INSERT INTO Users (user_name, email, password, role, status)
    VALUES ('gamer_pro_flow', 'submitter_flow@gamefit.vn', 'hash_pass', 'User', 'Active');
    SET @SubmitterId = SCOPE_IDENTITY();
END;

-- 3. Tạo User thành viên cộng đồng bình chọn (Voter)
DECLARE @VoterId INT;
SELECT @VoterId = user_id FROM Users WHERE email = 'voter_flow@gamefit.vn';
IF @VoterId IS NULL
BEGIN
    INSERT INTO Users (user_name, email, password, role, status)
    VALUES ('gamer_voter_flow', 'voter_flow@gamefit.vn', 'hash_pass', 'User', 'Active');
    SET @VoterId = SCOPE_IDENTITY();
END;

-- 4. Tạo User Quản trị viên (Admin Reviewer)
DECLARE @AdminId INT;
SELECT @AdminId = user_id FROM Users WHERE email = 'admin_flow@gamefit.vn';
IF @AdminId IS NULL
BEGIN
    INSERT INTO Users (user_name, email, password, role, status)
    VALUES ('admin_hardware_flow', 'admin_flow@gamefit.vn', 'hash_pass', 'Admin', 'Active');
    SET @AdminId = SCOPE_IDENTITY();
END;

-- 5. Tạo cấu hình PC trong User_pc cho Submitter
DECLARE @CpuId INT = (SELECT TOP 1 cpu_id FROM Cpus);
DECLARE @GpuId INT = (SELECT TOP 1 gpu_id FROM Gpus);
DECLARE @PcId INT;

SELECT @PcId = pc_id FROM User_pc WHERE user_id = @SubmitterId AND is_deleted = 0;
IF @PcId IS NULL
BEGIN
    INSERT INTO User_pc (user_id, pc_name, cpu_id, gpu_id, ram, storage, os, is_deleted)
    VALUES (@SubmitterId, N'Dàn PC Gaming i5 RTX 3060 Test Flow', @CpuId, @GpuId, 16, 512, 'Windows 11 64-bit', 0);
    SET @PcId = SCOPE_IDENTITY();
END;

-- 6. Dọn dẹp dữ liệu cũ nếu có
DELETE FROM Notifications WHERE user_id = @SubmitterId;
DELETE FROM Votes WHERE target_type = 'RECOMMENDATION' AND target_id IN (
    SELECT recommendation_id FROM Game_PC_Recommendation WHERE user_id = @SubmitterId
);
DELETE FROM Game_PC_Recommendation WHERE user_id = @SubmitterId;

PRINT N'-> Đã khởi tạo môi trường thành công:';
PRINT N'   + Game ID      : ' + CAST(@GameId AS VARCHAR(10));
PRINT N'   + Submitter ID : ' + CAST(@SubmitterId AS VARCHAR(10)) + N' (gamer_pro_flow)';
PRINT N'   + Voter ID     : ' + CAST(@VoterId AS VARCHAR(10)) + N' (gamer_voter_flow)';
PRINT N'   + Admin ID     : ' + CAST(@AdminId AS VARCHAR(10)) + N' (admin_hardware_flow)';
PRINT N'   + PC ID        : ' + CAST(@PcId AS VARCHAR(10)) + N' (Dàn PC Gaming i5 RTX 3060 Test Flow)';
GO


-- =========================================================================================
-- GIAI ĐOẠN 1: NGƯỜI DÙNG ĐĂNG ĐỀ XUẤT CẤU HÌNH & CỘNG ĐỒNG BÌNH CHỌN (UPVOTE)
-- Mục đích: Tạo bản ghi trong Game_PC_Recommendation và tăng điểm vote để đủ điều kiện kiểm duyệt
-- =========================================================================================
PRINT N'';
PRINT N'=========================================================================================';
PRINT N'GIAI ĐOẠN 1: TẠO ĐỀ XUẤT CẤU HÌNH MỚI VÀ CỘNG ĐỒNG BÌNH CHỌN (UPVOTE)';
PRINT N'=========================================================================================';

DECLARE @SubmitterId INT = (SELECT user_id FROM Users WHERE email = 'submitter_flow@gamefit.vn');
DECLARE @VoterId INT = (SELECT user_id FROM Users WHERE email = 'voter_flow@gamefit.vn');
DECLARE @GameId INT = (SELECT TOP 1 game_id FROM Games WHERE is_active = 1);
DECLARE @PcId INT = (SELECT pc_id FROM User_pc WHERE user_id = @SubmitterId AND is_deleted = 0);

-- Đăng đề xuất
INSERT INTO Game_PC_Recommendation (user_id, game_id, pc_id, type, note, status, is_hidden, created_at)
VALUES (@SubmitterId, @GameId, @PcId, 'RECOMMENDED', N'Cấu hình chiến game siêu mượt 1080p Ultra setting', 'PENDING', 0, GETDATE());

DECLARE @RecId INT = SCOPE_IDENTITY();

-- Cộng đồng vote ủng hộ (+1 Upvote)
INSERT INTO Votes (user_id, target_type, target_id, vote_type, created_at)
VALUES (@VoterId, 'RECOMMENDATION', @RecId, 1, GETDATE());

PRINT N'-> KẾT QUẢ 1:';
PRINT N'   + Đề xuất Recommendation ID = ' + CAST(@RecId AS VARCHAR(10)) + N' đã được tạo với status = PENDING.';
PRINT N'   + Cộng đồng đã Upvote thành công (net_votes = 1), đủ điều kiện vượt qua bộ lọc min_votes!';
GO


-- =========================================================================================
-- GIAI ĐOẠN 2: ADMIN TRUY VẤN DANH SÁCH ĐỀ XUẤT CẦN DUYỆT (sp_Admin_GetGamePCRecommendations)
-- Mục đích: Màn hình kiểm duyệt của Admin hiển thị danh sách các máy có điểm vote cao
-- =========================================================================================
PRINT N'';
PRINT N'=========================================================================================';
PRINT N'GIAI ĐOẠN 2: ADMIN GỌI sp_Admin_GetGamePCRecommendations ĐỂ LẤY BÀI CHỜ DUYỆT';
PRINT N'=========================================================================================';

EXEC sp_Admin_GetGamePCRecommendations 
    @status = 'PENDING', 
    @type = 'RECOMMENDED', 
    @search = NULL, 
    @min_votes = 1;

PRINT N'-> KẾT QUẢ 2: sp_Admin_GetGamePCRecommendations trả về danh sách đầy đủ linh kiện, benchmark và điểm vote.';
GO


-- =========================================================================================
-- GIAI ĐOẠN 3: ADMIN MỞ CHI TIẾT ĐỂ SO SÁNH CẤU HÌNH (sp_Admin_GetRecommendationDetail)
-- Mục đích: Modal popup hiện ra 2 bảng đối chiếu cấu hình máy user và cấu hình chuẩn của game
-- =========================================================================================
PRINT N'';
PRINT N'=========================================================================================';
PRINT N'GIAI ĐOẠN 3: ADMIN GỌI sp_Admin_GetRecommendationDetail ĐỐI CHIẾU 2 RESULT SETS';
PRINT N'=========================================================================================';

DECLARE @SubmitterId INT = (SELECT user_id FROM Users WHERE email = 'submitter_flow@gamefit.vn');
DECLARE @RecId INT = (SELECT TOP 1 recommendation_id FROM Game_PC_Recommendation WHERE user_id = @SubmitterId);

EXEC sp_Admin_GetRecommendationDetail @recommendation_id = @RecId;

PRINT N'-> KẾT QUẢ 3: Admin xem được trực tiếp 2 bảng: Thông số máy đề xuất (Bảng 1) VS Cấu hình chuẩn của game (Bảng 2).';
GO


-- =========================================================================================
-- GIAI ĐOẠN 4: ADMIN TỪ CHỐI ĐỀ XUẤT DO CHƯA PHÙ HỢP (sp_Admin_RejectRecommendation)
-- Mục đích: Đổi status = 'REJECTED' và tự động sinh Notification gửi tới người dùng
-- =========================================================================================
PRINT N'';
PRINT N'=========================================================================================';
PRINT N'GIAI ĐOẠN 4: ADMIN GỌI sp_Admin_RejectRecommendation TỪ CHỐI KÈM LÝ DO CỤ THỂ';
PRINT N'=========================================================================================';

DECLARE @SubmitterId INT = (SELECT user_id FROM Users WHERE email = 'submitter_flow@gamefit.vn');
DECLARE @AdminId INT = (SELECT user_id FROM Users WHERE email = 'admin_flow@gamefit.vn');
DECLARE @RecId INT = (SELECT TOP 1 recommendation_id FROM Game_PC_Recommendation WHERE user_id = @SubmitterId);

-- Admin từ chối
EXEC sp_Admin_RejectRecommendation 
    @recommendation_id = @RecId, 
    @admin_id = @AdminId, 
    @reject_reason = N'Dung lượng RAM 16GB đạt chuẩn nhưng GPU chưa đủ mạnh để gánh mức đồ họa Ultra 60 FPS như mô tả.';

PRINT N'[4.1] Bảng Game_PC_Recommendation sau khi bị từ chối:';
SELECT recommendation_id, user_id, status, reviewed_by, reviewed_at, reject_reason
FROM Game_PC_Recommendation
WHERE recommendation_id = @RecId;

PRINT N'[4.2] Bảng Notifications tự động sinh thông báo cho người dùng:';
SELECT notification_id, user_id, title, message, type, target_url, created_at
FROM Notifications
WHERE user_id = @SubmitterId
ORDER BY created_at DESC;

PRINT N'-> KẾT QUẢ 4:';
PRINT N'   + status = REJECTED.';
PRINT N'   + Người dùng nhận được thông báo giải thích rõ ràng lý do từ chối!';
GO


-- =========================================================================================
-- GIAI ĐOẠN 5: NGƯỜI DÙNG ẨN ĐỀ XUẤT CỦA MÌNH (sp_HideGamePCRecommendation)
-- Mục đích: Kiểm chứng cơ chế XÓA MỀM (Soft Delete) qua trigger INSTEAD OF DELETE
-- =========================================================================================
PRINT N'';
PRINT N'=========================================================================================';
PRINT N'GIAI ĐOẠN 5: USER GỌI sp_HideGamePCRecommendation & KIỂM CHỨNG TRIGGER XÓA MỀM';
PRINT N'=========================================================================================';

DECLARE @SubmitterId INT = (SELECT user_id FROM Users WHERE email = 'submitter_flow@gamefit.vn');
DECLARE @RecId INT = (SELECT TOP 1 recommendation_id FROM Game_PC_Recommendation WHERE user_id = @SubmitterId);

-- User gọi ẩn đề xuất
EXEC sp_HideGamePCRecommendation 
    @user_id = @SubmitterId, 
    @recommendation_id = @RecId;

PRINT N'[5.1] Kiểm tra bản ghi trong bảng Game_PC_Recommendation:';
SELECT recommendation_id, user_id, is_hidden, status, reject_reason
FROM Game_PC_Recommendation
WHERE recommendation_id = @RecId;

PRINT N'-> KẾT QUẢ 5:';
PRINT N'   + Dòng dữ liệu KHÔNG bị xóa mất khỏi CSDL.';
PRINT N'   + Trigger trg_GamePCRec_InsteadOfDelete đã tự động chuyển is_hidden = 1 (Xóa mềm thành công)!';
GO


-- -----------------------------------------------------------------------------------------
-- BƯỚC CLEANUP: DỌN DẸP DỮ LIỆU TEST
-- -----------------------------------------------------------------------------------------
PRINT N'';
PRINT N'-----------------------------------------------------------------------------------------';
PRINT N'DỌN DẸP DỮ LIỆU TEST (CLEANUP)';
PRINT N'-----------------------------------------------------------------------------------------';

DECLARE @SubmitterId INT = (SELECT user_id FROM Users WHERE email = 'submitter_flow@gamefit.vn');
DECLARE @VoterId INT = (SELECT user_id FROM Users WHERE email = 'voter_flow@gamefit.vn');
DECLARE @AdminId INT = (SELECT user_id FROM Users WHERE email = 'admin_flow@gamefit.vn');

IF @SubmitterId IS NOT NULL
BEGIN
    DELETE FROM Notifications WHERE user_id = @SubmitterId;
    DELETE FROM Votes WHERE target_type = 'RECOMMENDATION' AND user_id IN (@SubmitterId, @VoterId);
    
    -- Tắt tạm trigger để xóa cứng dọn dẹp
    ALTER TABLE Game_PC_Recommendation DISABLE TRIGGER trg_GamePCRec_InsteadOfDelete;
    DELETE FROM Game_PC_Recommendation WHERE user_id = @SubmitterId;
    ALTER TABLE Game_PC_Recommendation ENABLE TRIGGER trg_GamePCRec_InsteadOfDelete;

    DELETE FROM User_pc WHERE user_id = @SubmitterId;
    DELETE FROM Users WHERE user_id IN (@SubmitterId, @VoterId, @AdminId);
END;

PRINT N'-> Đã dọn dẹp sạch sẽ toàn bộ dữ liệu test.';
GO

PRINT N'=========================================================================================';
PRINT N'HOÀN TẤT DEMO TOÀN DIỆN VÒNG ĐỜI ĐỀ XUẤT CẤU HÌNH PC';
PRINT N'=========================================================================================';
GO
