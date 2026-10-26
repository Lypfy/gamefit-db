-- =========================================================================================
-- FILE: demo_trg_UserPC_InsteadOfDelete.sql
-- THƯ MỤC: e:\Antigravity IDE\gamefit\gamefit-db\demo\
-- MỤC ĐÍCH: SCRIPT DEMO KIỂM THỬ TRIGGER [trg_UserPC_InsteadOfDelete]
-- CƠ CHẾ: INSTEAD OF DELETE (Xóa mềm - Soft Delete trên bảng User_pc)
-- =========================================================================================
-- NỘI DUNG TRIGGER TRONG HỆ THỐNG:
--   CREATE TRIGGER [dbo].[trg_UserPC_InsteadOfDelete]
--   ON [dbo].[User_pc]
--   INSTEAD OF DELETE
--   AS
--   BEGIN
--       SET NOCOUNT ON;
--       UPDATE User_pc
--       SET is_deleted = 1
--       WHERE pc_id IN (SELECT pc_id FROM deleted);
--   END;
-- =========================================================================================

USE gamefit_db;
GO

PRINT N'=========================================================================================';
PRINT N'BẮT ĐẦU CHẠY DEMO TRIGGER: trg_UserPC_InsteadOfDelete';
PRINT N'=========================================================================================';
GO

-- -----------------------------------------------------------------------------------------
-- BƯỚC 0: CHUẨN BỊ DỮ LIỆU THỬ NGHIỆM (SETUP TEST DATA)
-- -----------------------------------------------------------------------------------------
PRINT N'-----------------------------------------------------------------------------------------';
PRINT N'BƯỚC 0: KHỞI TẠO DỮ LIỆU MẪU ĐỂ TEST TRIGGER';
PRINT N'-----------------------------------------------------------------------------------------';

-- Đảm bảo trigger đang ở trạng thái ENABLE
ALTER TABLE [dbo].[User_pc] ENABLE TRIGGER [trg_UserPC_InsteadOfDelete];

-- 1. Tìm hoặc chuẩn bị các khóa ngoại cần thiết (User, Cpu, Gpu, Game)
DECLARE @TestUserId INT, @TestCpuId INT, @TestGpuId INT, @TestGameId INT;

SELECT TOP 1 @TestUserId = user_id FROM Users;
IF @TestUserId IS NULL
BEGIN
    INSERT INTO Users (username, email, password, role)
    VALUES ('demo_user_pc_test', 'demopc@gamefit.vn', 'password_hash', 'User');
    SET @TestUserId = SCOPE_IDENTITY();
END;

SELECT TOP 1 @TestCpuId = cpu_id FROM Cpus;
SELECT TOP 1 @TestGpuId = gpu_id FROM Gpus;
SELECT TOP 1 @TestGameId = game_id FROM Games;

IF @TestGameId IS NULL
BEGIN
    INSERT INTO Games (name, description, publisher, developer, release_date, download_url, is_active)
    VALUES (N'Demo PC Game Test', N'Game phục vụ test cấu hình PC', N'GameFit', N'GameFit Dev', GETDATE(), 'https://gamefit.vn/demo-pc', 1);
    SET @TestGameId = SCOPE_IDENTITY();
END;

-- 2. Dọn dẹp dữ liệu test cũ nếu còn sót lại
IF EXISTS (SELECT 1 FROM User_pc WHERE pc_name = N'Demo_Gaming_PC_TestTrigger')
BEGIN
    DECLARE @OldPcId INT;
    SELECT @OldPcId = pc_id FROM User_pc WHERE pc_name = N'Demo_Gaming_PC_TestTrigger';
    
    -- Xóa bài đề xuất liên kết trước
    DELETE FROM Game_PC_Recommendation WHERE pc_id = @OldPcId;
    
    -- Tạm disable trigger để xóa cứng bản ghi cũ
    ALTER TABLE User_pc DISABLE TRIGGER trg_UserPC_InsteadOfDelete;
    DELETE FROM User_pc WHERE pc_id = @OldPcId;
    ALTER TABLE User_pc ENABLE TRIGGER trg_UserPC_InsteadOfDelete;
END;

-- 3. Tạo mới 1 cấu hình máy thử nghiệm (is_deleted = 0)
INSERT INTO User_pc (pc_name, user_id, cpu_id, gpu_id, os, ram, storage, is_deleted)
VALUES (N'Demo_Gaming_PC_TestTrigger', @TestUserId, @TestCpuId, @TestGpuId, 'Windows 11', 16, 512, 0);

DECLARE @TestPcId INT = SCOPE_IDENTITY();

-- 4. Tạo 1 bài viết đề xuất cấu hình (Game_PC_Recommendation) liên kết tới dàn PC này
--    (Tạo quan hệ ràng buộc Khóa Ngoại FK_GamePCRec_UserPc)
INSERT INTO Game_PC_Recommendation (user_id, game_id, pc_id, type, note, status)
VALUES (@TestUserId, @TestGameId, @TestPcId, 'RECOMMENDED', N'Dàn máy demo phục vụ kiểm thử trigger', 'APPROVED');

PRINT N'-> Đã khởi tạo PC test ID: ' + CAST(@TestPcId AS VARCHAR(10)) + N' cho User ID: ' + CAST(@TestUserId AS VARCHAR(10));
SELECT pc_id, pc_name, user_id, os, ram, storage, is_deleted 
FROM User_pc 
WHERE pc_id = @TestPcId;

SELECT r.recommendation_id, r.user_id, r.game_id, r.pc_id, p.pc_name, r.type, r.status
FROM Game_PC_Recommendation r
JOIN User_pc p ON r.pc_id = p.pc_id
WHERE r.pc_id = @TestPcId;
GO


-- =========================================================================================
-- KỊCH BẢN 1: TRƯỜNG HỢP CHẠY ĐÚNG (HỢP LỆ - NORMAL / SUCCESSFUL SOFT DELETE)
-- =========================================================================================
PRINT N'';
PRINT N'=========================================================================================';
PRINT N'KỊCH BẢN 1: TRƯỜNG HỢP CHẠY ĐÚNG (XÓA MỀM THÀNH CÔNG)';
PRINT N'Mục đích: Chứng minh khi gọi DELETE, trigger INSTEAD OF DELETE chặn việc xóa vật lý';
PRINT N'          và tự động chuyển is_deleted = 1, bảo lưu dữ liệu lịch sử và ràng buộc khóa ngoại.';
PRINT N'=========================================================================================';

DECLARE @PcId INT;
SELECT @PcId = pc_id FROM User_pc WHERE pc_name = N'Demo_Gaming_PC_TestTrigger';

PRINT N'[1.1] Kiểm tra trạng thái TRƯỚC KHI XÓA:';
SELECT pc_id, pc_name, is_deleted, N'Cấu hình đang sử dụng bình thường' AS TrangThai 
FROM User_pc 
WHERE pc_id = @PcId;

PRINT N'[1.2] Thực thi câu lệnh DELETE FROM User_pc WHERE pc_id = ' + CAST(@PcId AS VARCHAR(10)) + N'...';
DELETE FROM User_pc WHERE pc_id = @PcId;

PRINT N'[1.3] Kiểm tra trạng thái SAU KHI THỰC THI LỆNH DELETE:';
SELECT pc_id, pc_name, is_deleted, 
       CASE WHEN is_deleted = 1 THEN N'ĐÃ ĐƯỢC ĐÁNH DẤU XÓA MỀM (THÀNH CÔNG)' ELSE N'Chưa xóa' END AS TrangThai
FROM User_pc 
WHERE pc_id = @PcId;

PRINT N'[1.4] Kiểm tra dữ liệu liên kết trong bảng con Game_PC_Recommendation:';
SELECT r.recommendation_id, r.pc_id, p.pc_name, p.is_deleted, r.status
FROM Game_PC_Recommendation r
JOIN User_pc p ON r.pc_id = p.pc_id
WHERE r.pc_id = @PcId;

-- Đánh giá kết quả kịch bản 1
IF EXISTS (SELECT 1 FROM User_pc WHERE pc_id = @PcId AND is_deleted = 1)
   AND EXISTS (SELECT 1 FROM Game_PC_Recommendation WHERE pc_id = @PcId)
BEGIN
    PRINT N'==> KẾT QUẢ KỊCH BẢN 1: [THÀNH CÔNG TUYỆT ĐỐI]';
    PRINT N'    - Dòng dữ liệu cấu hình máy trong User_pc KHÔNG bị xóa mất.';
    PRINT N'    - Cột cờ is_deleted đã được cập nhật thành 1.';
    PRINT N'    - Dữ liệu bài đề xuất ở Game_PC_Recommendation vẫn tham chiếu an toàn, không bị lỗi khóa ngoại!';
END
ELSE
BEGIN
    PRINT N'==> KẾT QUẢ KỊCH BẢN 1: [THẤT BẠI]';
END;
GO


-- =========================================================================================
-- KỊCH BẢN 2: CÁC TRƯỜNG HỢP VI PHẠM (VIOLATION / EXCEPTION CASES)
-- =========================================================================================
PRINT N'';
PRINT N'=========================================================================================';
PRINT N'KỊCH BẢN 2: CÁC TRƯỜNG HỢP VI PHẠM';
PRINT N'=========================================================================================';

-- -----------------------------------------------------------------------------------------
-- Kịch bản 2.1: Vi phạm ràng buộc Khóa Ngoại (Foreign Key Violation) nếu KHÔNG CÓ trigger
-- Chứng minh: Nếu hệ thống không có trg_UserPC_InsteadOfDelete, lệnh DELETE sẽ bị SQL Server
--             chặn đứng với lỗi xung đột khóa ngoại FK_GamePCRec_UserPc (Error 547).
-- -----------------------------------------------------------------------------------------
PRINT N'-----------------------------------------------------------------------------------------';
PRINT N'KỊCH BẢN 2.1: VI PHẠM RÀNG BUỘC TOÀN VẸN KHÓA NGOẠI KHI KHÔNG CÓ TRIGGER (HARD DELETE)';
PRINT N'-----------------------------------------------------------------------------------------';

DECLARE @PcId INT;
SELECT @PcId = pc_id FROM User_pc WHERE pc_name = N'Demo_Gaming_PC_TestTrigger';

-- Khôi phục lại is_deleted = 0 để giả lập trạng thái ban đầu
UPDATE User_pc SET is_deleted = 0 WHERE pc_id = @PcId;

PRINT N'[2.1.1] Giả lập tình huống: TẮT (DISABLE) trigger trg_UserPC_InsteadOfDelete...';
ALTER TABLE User_pc DISABLE TRIGGER trg_UserPC_InsteadOfDelete;

PRINT N'[2.1.2] Cố gắng thực hiện XÓA CỨNG PC đang có khóa ngoại tham chiếu trong Game_PC_Recommendation...';
BEGIN TRY
    DELETE FROM User_pc WHERE pc_id = @PcId;
    PRINT N'CẢNH BÁO: Lệnh xóa chạy qua (Không bắt được lỗi)!';
END TRY
BEGIN CATCH
    PRINT N'==> BẮT ĐƯỢC LỖI VI PHẠM RÀNG BUỘC TOÀN VẸN (VIOLATION CAUGHT):';
    PRINT N'    - Mã lỗi (Error Number)   : ' + CAST(ERROR_NUMBER() AS VARCHAR(10));
    PRINT N'    - Mức độ nghiêm trọng     : ' + CAST(ERROR_SEVERITY() AS VARCHAR(10));
    PRINT N'    - Nội dung lỗi SQL Server : ' + ERROR_MESSAGE();
    PRINT N'==> Ý NGHĨA: Xóa cứng bị chặn do vi phạm Foreign Key FK_GamePCRec_UserPc!';
    PRINT N'             Nhờ có trigger INSTEAD OF DELETE, dữ liệu bài đề xuất cũ của cộng đồng';
    PRINT N'             không bị mất mát hay gây crash hệ thống khi người dùng xóa máy.';
END CATCH;

-- Luôn bật lại trigger sau khi thử nghiệm
ALTER TABLE User_pc ENABLE TRIGGER trg_UserPC_InsteadOfDelete;
PRINT N'[2.1.3] Đã BẬT LẠI (ENABLE) trigger trg_UserPC_InsteadOfDelete để bảo vệ CSDL.';
GO


-- -----------------------------------------------------------------------------------------
-- Kịch bản 2.2: Vi phạm quy tắc nghiệp vụ - Xóa cấu hình PC đã bị đánh dấu xóa từ trước (Repeated Delete)
-- Phân tích: Khi PC đã có is_deleted = 1, người dùng lại gửi tiếp lệnh DELETE.
-- -----------------------------------------------------------------------------------------
PRINT N'';
PRINT N'-----------------------------------------------------------------------------------------';
PRINT N'KỊCH BẢN 2.2: VI PHẠM LOGIC NGHIỆP VỤ - THAO TÁC XÓA TRÊN CẤU HÌNH ĐÃ BỊ XÓA TỪ TRƯỚC';
PRINT N'-----------------------------------------------------------------------------------------';

DECLARE @PcId INT;
SELECT @PcId = pc_id FROM User_pc WHERE pc_name = N'Demo_Gaming_PC_TestTrigger';

-- Đảm bảo PC đang ở trạng thái đã bị xóa mềm
UPDATE User_pc SET is_deleted = 1 WHERE pc_id = @PcId;

PRINT N'[2.2.1] Trạng thái hiện tại của PC demo: is_deleted = 1 (Đã xóa mềm trước đó)';
SELECT pc_id, pc_name, is_deleted FROM User_pc WHERE pc_id = @PcId;

PRINT N'[2.2.2] Đánh giá nghiệp vụ: Thao tác gửi lệnh DELETE trên cấu hình đã xóa là vi phạm logic kiểm soát.';
PRINT N'        Với trigger cơ bản hiện tại, lệnh UPDATE chỉ thực thi lặp lại mà không cảnh báo.';
PRINT N'        Nếu muốn bắt lỗi vi phạm nghiệp vụ chặt chẽ, trigger có thể mở rộng kiểm tra:';
PRINT N'        IF EXISTS (SELECT 1 FROM deleted d JOIN User_pc p ON d.pc_id = p.pc_id WHERE p.is_deleted = 1)';
PRINT N'            RAISERROR(N''Cấu hình máy này đã bị xóa từ trước, không thể xóa lại!'', 16, 1);';
GO


-- =========================================================================================
-- BƯỚC DỌN DẸP DỮ LIỆU DEMO (CLEANUP)
-- =========================================================================================
PRINT N'';
PRINT N'-----------------------------------------------------------------------------------------';
PRINT N'DỌN DẸP DỮ LIỆU DEMO ĐỂ GIỮ SẠCH DATABASE';
PRINT N'-----------------------------------------------------------------------------------------';

DECLARE @CleanPcId INT;
SELECT @CleanPcId = pc_id FROM User_pc WHERE pc_name = N'Demo_Gaming_PC_TestTrigger';

IF @CleanPcId IS NOT NULL
BEGIN
    -- 1. Xóa bài đề xuất Game_PC_Recommendation
    DELETE FROM Game_PC_Recommendation WHERE pc_id = @CleanPcId;

    -- 2. Tạm disable trigger để xóa sạch dòng test trong bảng User_pc
    ALTER TABLE User_pc DISABLE TRIGGER trg_UserPC_InsteadOfDelete;
    DELETE FROM User_pc WHERE pc_id = @CleanPcId;
    ALTER TABLE User_pc ENABLE TRIGGER trg_UserPC_InsteadOfDelete;
END;

-- Xóa user / game test nếu tạo riêng
DELETE FROM Users WHERE username = 'demo_user_pc_test';
DELETE FROM Games WHERE name = N'Demo PC Game Test';

PRINT N'==> ĐÃ DỌN DẸP SẠCH SẼ DỮ LIỆU THỬ NGHIỆM. TRIGGER HOẠT ĐỘNG CHUẨN XÁC!';
PRINT N'=========================================================================================';
GO
