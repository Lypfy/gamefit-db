-- =========================================================================================
-- FILE: demo_trg_Tags_InsteadOfDelete.sql
-- THƯ MỤC: e:\Antigravity IDE\gamefit\gamefit-db\demo\
-- MỤC ĐÍCH: SCRIPT DEMO KIỂM THỬ TRIGGER [trg_Tags_InsteadOfDelete]
-- CƠ CHẾ: INSTEAD OF DELETE (Xóa mềm - Soft Delete trên bảng Tags)
-- =========================================================================================
-- NỘI DUNG TRIGGER TRONG HỆ THỐNG:
--   CREATE TRIGGER [dbo].[trg_Tags_InsteadOfDelete]
--   ON [dbo].[Tags]
--   INSTEAD OF DELETE
--   AS
--   BEGIN
--       SET NOCOUNT ON;
--       UPDATE Tags
--       SET is_hidden = 1
--       WHERE tag_id IN (SELECT tag_id FROM deleted);
--   END;
-- =========================================================================================

USE gamefit_db;
GO

PRINT N'=========================================================================================';
PRINT N'BẮT ĐẦU CHẠY DEMO TRIGGER: trg_Tags_InsteadOfDelete';
PRINT N'=========================================================================================';
GO

-- -----------------------------------------------------------------------------------------
-- BƯỚC 0: CHUẨN BỊ DỮ LIỆU THỬ NGHIỆM (SETUP TEST DATA)
-- -----------------------------------------------------------------------------------------
PRINT N'-----------------------------------------------------------------------------------------';
PRINT N'BƯỚC 0: KHỞI TẠO DỮ LIỆU MẪU ĐỂ TEST TRIGGER';
PRINT N'-----------------------------------------------------------------------------------------';

-- Đảm bảo trigger đang ở trạng thái ENABLE
ALTER TABLE [dbo].[Tags] ENABLE TRIGGER [trg_Tags_InsteadOfDelete];

-- 1. Tìm hoặc tạo Game để liên kết
DECLARE @TestGameId INT;
SELECT TOP 1 @TestGameId = game_id FROM Games WHERE is_active = 1;

IF @TestGameId IS NULL
BEGIN
    INSERT INTO Games (name, description, publisher, developer, release_date, download_url, is_active)
    VALUES (N'Demo Trigger Test Game', N'Game phục vụ test trigger', N'GameFit', N'GameFit Dev', GETDATE(), 'https://gamefit.vn/demo', 1);
    SET @TestGameId = SCOPE_IDENTITY();
END;

-- 2. Dọn dẹp dữ liệu test cũ nếu tồn tại
IF EXISTS (SELECT 1 FROM Tags WHERE name = N'Demo_Tag_TestTrigger')
BEGIN
    DECLARE @OldTagId INT;
    SELECT @OldTagId = tag_id FROM Tags WHERE name = N'Demo_Tag_TestTrigger';
    DELETE FROM Games_Tags WHERE tag_id = @OldTagId;
    
    -- Tạm thời disable trigger để dọn dẹp vật lý tag cũ
    ALTER TABLE Tags DISABLE TRIGGER trg_Tags_InsteadOfDelete;
    DELETE FROM Tags WHERE tag_id = @OldTagId;
    ALTER TABLE Tags ENABLE TRIGGER trg_Tags_InsteadOfDelete;
END;

-- 3. Tạo mới 1 Tag test đang hoạt động bình thường (is_hidden = 0)
INSERT INTO Tags (name, is_hidden)
VALUES (N'Demo_Tag_TestTrigger', 0);

DECLARE @TestTagId INT = SCOPE_IDENTITY();

-- 4. Gán Tag test vào Game test (tạo quan hệ ràng buộc Khóa Ngoại FK_GT_Tags)
INSERT INTO Games_Tags (game_id, tag_id)
VALUES (@TestGameId, @TestTagId);

PRINT N'-> Đã khởi tạo Tag test ID: ' + CAST(@TestTagId AS VARCHAR(10)) + N' gán vào Game ID: ' + CAST(@TestGameId AS VARCHAR(10));
SELECT tag_id, name, is_hidden 
FROM Tags 
WHERE tag_id = @TestTagId;

SELECT gt.game_id, g.name AS GameName, gt.tag_id, t.name AS TagName
FROM Games_Tags gt
JOIN Games g ON gt.game_id = g.game_id
JOIN Tags t ON gt.tag_id = t.tag_id
WHERE gt.tag_id = @TestTagId;
GO


-- =========================================================================================
-- KỊCH BẢN 1: TRƯỜNG HỢP CHẠY ĐÚNG (HỢP LỆ - NORMAL / SUCCESSFUL SOFT DELETE)
-- =========================================================================================
PRINT N'';
PRINT N'=========================================================================================';
PRINT N'KỊCH BẢN 1: TRƯỜNG HỢP CHẠY ĐÚNG (XÓA MỀM THÀNH CÔNG)';
PRINT N'Mục đích: Chứng minh khi gọi DELETE, trigger INSTEAD OF DELETE chặn việc xóa vật lý';
PRINT N'          và tự động chuyển is_hidden = 1, bảo vệ toàn vẹn liên kết với bảng Games_Tags.';
PRINT N'=========================================================================================';

DECLARE @TagId INT;
SELECT @TagId = tag_id FROM Tags WHERE name = N'Demo_Tag_TestTrigger';

PRINT N'[1.1] Kiểm tra trạng thái TRƯỚC KHI XÓA:';
SELECT tag_id, name, is_hidden, N'Đang hiển thị bình thường' AS TrangThai 
FROM Tags 
WHERE tag_id = @TagId;

PRINT N'[1.2] Thực thi câu lệnh DELETE FROM Tags WHERE tag_id = ' + CAST(@TagId AS VARCHAR(10)) + N'...';
DELETE FROM Tags WHERE tag_id = @TagId;

PRINT N'[1.3] Kiểm tra trạng thái SAU KHI THỰC THI LỆNH DELETE:';
SELECT tag_id, name, is_hidden, 
       CASE WHEN is_hidden = 1 THEN N'ĐÃ BỊ ẨN (XÓA MỀM THÀNH CÔNG)' ELSE N'Chưa xóa' END AS TrangThai
FROM Tags 
WHERE tag_id = @TagId;

PRINT N'[1.4] Kiểm tra dữ liệu liên kết trong bảng con Games_Tags:';
SELECT gt.game_id, gt.tag_id, t.name AS TagName, t.is_hidden
FROM Games_Tags gt
JOIN Tags t ON gt.tag_id = t.tag_id
WHERE gt.tag_id = @TagId;

-- Đánh giá kết quả kịch bản 1
IF EXISTS (SELECT 1 FROM Tags WHERE tag_id = @TagId AND is_hidden = 1)
   AND EXISTS (SELECT 1 FROM Games_Tags WHERE tag_id = @TagId)
BEGIN
    PRINT N'==> KẾT QUẢ KỊCH BẢN 1: [THÀNH CÔNG TUYỆT ĐỐI]';
    PRINT N'    - Dòng dữ liệu trong bảng Tags KHÔNG bị xóa mất.';
    PRINT N'    - Cột cờ is_hidden đã được cập nhật thành 1.';
    PRINT N'    - Dữ liệu liên kết ở bảng Games_Tags vẫn tồn tại nguyên vẹn, không bị lỗi khóa ngoại!';
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
-- Chứng minh: Nếu hệ thống không có trg_Tags_InsteadOfDelete, lệnh DELETE sẽ bị SQL Server
--             chặn đứng với lỗi xung đột khóa ngoại FK_GT_Tags (Error 547).
-- -----------------------------------------------------------------------------------------
PRINT N'-----------------------------------------------------------------------------------------';
PRINT N'KỊCH BẢN 2.1: VI PHẠM RÀNG BUỘC TOÀN VẸN KHÓA NGOẠI KHI KHÔNG CÓ TRIGGER (HARD DELETE)';
PRINT N'-----------------------------------------------------------------------------------------';

DECLARE @TagId INT;
SELECT @TagId = tag_id FROM Tags WHERE name = N'Demo_Tag_TestTrigger';

-- Khôi phục lại is_hidden = 0 để giả lập trạng thái ban đầu
UPDATE Tags SET is_hidden = 0 WHERE tag_id = @TagId;

PRINT N'[2.1.1] Giả lập tình huống: TẮT (DISABLE) trigger trg_Tags_InsteadOfDelete...';
ALTER TABLE Tags DISABLE TRIGGER trg_Tags_InsteadOfDelete;

PRINT N'[2.1.2] Cố gắng thực hiện XÓA CỨNG Tag đang có khóa ngoại tham chiếu trong Games_Tags...';
BEGIN TRY
    DELETE FROM Tags WHERE tag_id = @TagId;
    PRINT N'CẢNH BÁO: Lệnh xóa chạy qua (Không bắt được lỗi)!';
END TRY
BEGIN CATCH
    PRINT N'==> BẮT ĐƯỢC LỖI VI PHẠM RÀNG BUỘC TOÀN VẸN (VIOLATION CAUGHT):';
    PRINT N'    - Mã lỗi (Error Number)   : ' + CAST(ERROR_NUMBER() AS VARCHAR(10));
    PRINT N'    - Mức độ nghiêm trọng     : ' + CAST(ERROR_SEVERITY() AS VARCHAR(10));
    PRINT N'    - Nội dung lỗi SQL Server : ' + ERROR_MESSAGE();
    PRINT N'==> Ý NGHĨA: Xóa cứng bị chặn do vi phạm Foreign Key FK_GT_Tags! Điều này chứng minh';
    PRINT N'             trigger INSTEAD OF DELETE là giải pháp bắt buộc để giải quyết bài toán.';
END CATCH;

-- Luôn bật lại trigger sau khi thử nghiệm
ALTER TABLE Tags ENABLE TRIGGER trg_Tags_InsteadOfDelete;
PRINT N'[2.1.3] Đã BẬT LẠI (ENABLE) trigger trg_Tags_InsteadOfDelete để bảo vệ CSDL.';
GO


-- -----------------------------------------------------------------------------------------
-- Kịch bản 2.2: Vi phạm quy tắc nghiệp vụ - Xóa thẻ Tag đã bị ẩn từ trước (Stale / Repeated Delete)
-- Phân tích: Khi một Tag đã bị ẩn (is_hidden = 1), người dùng/admin lại gửi tiếp lệnh DELETE.
-- -----------------------------------------------------------------------------------------
PRINT N'';
PRINT N'-----------------------------------------------------------------------------------------';
PRINT N'KỊCH BẢN 2.2: VI PHẠM LOGIC NGHIỆP VỤ - THAO TÁC XÓA TRÊN TAG ĐÃ BỊ ẨN TỪ TRƯỚC';
PRINT N'-----------------------------------------------------------------------------------------';

DECLARE @TagId INT;
SELECT @TagId = tag_id FROM Tags WHERE name = N'Demo_Tag_TestTrigger';

-- Đảm bảo tag đang ở trạng thái đã bị ẩn
UPDATE Tags SET is_hidden = 1 WHERE tag_id = @TagId;

PRINT N'[2.2.1] Trạng thái hiện tại của Tag demo: is_hidden = 1 (Đã xóa mềm trước đó)';
SELECT tag_id, name, is_hidden FROM Tags WHERE tag_id = @TagId;

PRINT N'[2.2.2] Đánh giá nghiệp vụ: Thao tác gửi lệnh DELETE trên đối tượng đã ẩn là vi phạm logic thao tác.';
PRINT N'        Với trigger cơ bản hiện tại, lệnh UPDATE chỉ thực thi lặp lại mà không cảnh báo.';
PRINT N'        Nếu muốn bắt lỗi vi phạm nghiệp vụ chặt chẽ, trigger có thể mở rộng kiểm tra:';
PRINT N'        IF EXISTS (SELECT 1 FROM deleted d JOIN Tags t ON d.tag_id = t.tag_id WHERE t.is_hidden = 1)';
PRINT N'            RAISERROR(N''Thẻ Tag này đã bị ẩn từ trước, không thể xóa lại!'', 16, 1);';
GO


-- =========================================================================================
-- BƯỚC DỌN DẸP DỮ LIỆU DEMO (CLEANUP)
-- =========================================================================================
PRINT N'';
PRINT N'-----------------------------------------------------------------------------------------';
PRINT N'DỌN DẸP DỮ LIỆU DEMO ĐỂ GIỮ SẠCH DATABASE';
PRINT N'-----------------------------------------------------------------------------------------';

DECLARE @CleanTagId INT;
SELECT @CleanTagId = tag_id FROM Tags WHERE name = N'Demo_Tag_TestTrigger';

IF @CleanTagId IS NOT NULL
BEGIN
    -- 1. Xóa liên kết Games_Tags
    DELETE FROM Games_Tags WHERE tag_id = @CleanTagId;

    -- 2. Tạm disable trigger để xóa sạch dòng test trong bảng Tags
    ALTER TABLE Tags DISABLE TRIGGER trg_Tags_InsteadOfDelete;
    DELETE FROM Tags WHERE tag_id = @CleanTagId;
    ALTER TABLE Tags ENABLE TRIGGER trg_Tags_InsteadOfDelete;
END;

-- Xóa game test nếu được tạo riêng
DELETE FROM Games WHERE name = N'Demo Trigger Test Game';

PRINT N'==> ĐÃ DỌN DẸP SẠCH SẼ DỮ LIỆU THỬ NGHIỆM. TRIGGER HOẠT ĐỘNG CHUẨN XÁC!';
PRINT N'=========================================================================================';
GO
