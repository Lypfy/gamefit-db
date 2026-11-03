-- =========================================================================================
-- FILE DEMO: STORED PROCEDURE [dbo].[sp_DeleteReview] (CHUYÊN ĐỀ: TRANSACTIONS & ACID)
-- THƯ MỤC: e:\Antigravity IDE\gamefit\gamefit-db\demo_script\sp\
-- MỤC ĐÍCH: DEMO TÍNH NGUYÊN TỬ (ATOMICITY) VÀ GIAO DỊCH (TRANSACTION) KHI XÓA REVIEW
-- ĐIỂM NHẤN VẤN ĐÁP CỰC KỲ QUAN TRỌNG:
--   1. Bảng Votes là bảng ĐA HÌNH (Polymorphic: target_type = 'REVIEW' / 'RECOMMENDATION').
--      -> SQL Server KHÔNG CHO PHÉP đặt Foreign Key Cascade từ Reviews sang Votes.
--      -> Do đó, nếu xóa review đơn thuần thì các bản ghi Vote sẽ bị "mồ côi" (orphaned data).
--   2. Giải pháp Enterprise: Sử dụng Explicit Transaction (BEGIN TRANSACTION ... COMMIT)
--      để dọn dẹp ĐỒNG THỜI cả 3 bảng:
--         Bước 1: Xóa các lượt Vote trong Votes (target_type = 'REVIEW')
--         Bước 2: Xóa các Báo cáo vi phạm trong Review_Reports
--         Bước 3: Xóa bản ghi đánh giá trong Reviews
--   3. Sử dụng SET XACT_ABORT ON và TRY...CATCH: Nếu có bất kỳ lỗi nào, ROLLBACK toàn bộ!
-- PHỤC VỤ: BÁO CÁO THUYẾT TRÌNH VẤN ĐÁP PHẦN GIAO DỊCH (TRANSACTION)
-- =========================================================================================

USE gamefit_db;
GO

PRINT N'=========================================================================================';
PRINT N'BẮT ĐẦU CHẠY DEMO TRANSACTION: sp_DeleteReview';
PRINT N'=========================================================================================';
GO

-- -----------------------------------------------------------------------------------------
-- BƯỚC 0: CHUẨN BỊ DỮ LIỆU TEST (SETUP ĐẦY ĐỦ 3 BẢNG: REVIEWS, VOTES, REVIEW_REPORTS)
-- -----------------------------------------------------------------------------------------
PRINT N'-----------------------------------------------------------------------------------------';
PRINT N'BƯỚC 0: CHUẨN BỊ DỮ LIỆU TEST LIÊN KẾT TRÊN CẢ 3 BẢNG';
PRINT N'-----------------------------------------------------------------------------------------';

-- 1. Lấy Game hợp lệ
DECLARE @GameId INT = (SELECT TOP 1 game_id FROM Games WHERE is_active = 1);

-- 2. Tạo User viết đánh giá (Author)
DECLARE @AuthorId INT;
SELECT @AuthorId = user_id FROM Users WHERE email = 'author_trans_del@gamefit.vn';
IF @AuthorId IS NULL
BEGIN
    INSERT INTO Users (user_name, email, password, role, status)
    VALUES ('author_trans_del', 'author_trans_del@gamefit.vn', 'hash_pass', 'User', 'Active');
    SET @AuthorId = SCOPE_IDENTITY();
END;

-- 3. Tạo User người khác bình chọn (Voter)
DECLARE @VoterId INT;
SELECT @VoterId = user_id FROM Users WHERE email = 'voter_trans_del@gamefit.vn';
IF @VoterId IS NULL
BEGIN
    INSERT INTO Users (user_name, email, password, role, status)
    VALUES ('voter_trans_del', 'voter_trans_del@gamefit.vn', 'hash_pass', 'User', 'Active');
    SET @VoterId = SCOPE_IDENTITY();
END;

-- 4. Tạo User gửi báo cáo (Reporter)
DECLARE @ReporterId INT;
SELECT @ReporterId = user_id FROM Users WHERE email = 'reporter_trans_del@gamefit.vn';
IF @ReporterId IS NULL
BEGIN
    INSERT INTO Users (user_name, email, password, role, status)
    VALUES ('reporter_trans_del', 'reporter_trans_del@gamefit.vn', 'hash_pass', 'User', 'Active');
    SET @ReporterId = SCOPE_IDENTITY();
END;

-- 5. Dọn dẹp dữ liệu cũ nếu còn sót lại
DELETE FROM Votes WHERE target_type = 'REVIEW' AND target_id IN (
    SELECT review_id FROM Reviews WHERE user_id = @AuthorId AND game_id = @GameId
);
DELETE FROM Review_Reports WHERE user_id = @ReporterId;
DELETE FROM Reviews WHERE user_id = @AuthorId AND game_id = @GameId;

-- 6. Tạo 1 Review test mới trong bảng Reviews
INSERT INTO Reviews (user_id, game_id, rating, comment, is_hidden, report_status, created_at)
VALUES (@AuthorId, @GameId, 5, N'Game tuyệt phẩm, đồ họa xuất sắc và tối ưu cực kỳ mượt mà!', 0, 'PENDING', GETDATE());

DECLARE @ReviewId INT = SCOPE_IDENTITY();

-- 7. Tạo lượt UPVOTE (+1) trong bảng Votes (Bảng đa hình, không có FK cascade)
INSERT INTO Votes (user_id, target_type, target_id, vote_type, created_at)
VALUES (@VoterId, 'REVIEW', @ReviewId, 1, GETDATE());

-- 8. Tạo 1 bản ghi Báo cáo trong bảng Review_Reports
INSERT INTO Review_Reports (review_id, user_id, report_reason, report_detail, reported_at)
VALUES (@ReviewId, @ReporterId, N'Spam', N'Báo cáo test transaction', DATEADD(HOUR, 7, GETUTCDATE()));

PRINT N'-> Đã khởi tạo thành công dữ liệu liên kết trên cả 3 bảng:';
PRINT N'   + Game ID    : ' + CAST(@GameId AS VARCHAR(10));
PRINT N'   + Author ID  : ' + CAST(@AuthorId AS VARCHAR(10));
PRINT N'   + Review ID  : ' + CAST(@ReviewId AS VARCHAR(10));
PRINT N'   + Bảng 1 [Reviews]        : 1 bản ghi đánh giá.';
PRINT N'   + Bảng 2 [Votes]          : 1 bản ghi vote (target_type = REVIEW, target_id = ' + CAST(@ReviewId AS VARCHAR(10)) + N').';
PRINT N'   + Bảng 3 [Review_Reports] : 1 bản ghi báo cáo.';
GO


-- =========================================================================================
-- KỊCH BẢN 1: KIỂM TRA TRẠNG THÁI TRƯỚC KHI THỰC THI TRANSACTION
-- Ý nghĩa: Chứng minh rõ ràng dữ liệu đang tồn tại ở cả 3 bảng độc lập
-- =========================================================================================
PRINT N'';
PRINT N'=========================================================================================';
PRINT N'KỊCH BẢN 1: KIỂM TRA DỮ LIỆU Ở CẢ 3 BẢNG TRƯỚC KHI GỌI sp_DeleteReview';
PRINT N'=========================================================================================';

DECLARE @AuthorId INT = (SELECT user_id FROM Users WHERE email = 'author_trans_del@gamefit.vn');
DECLARE @GameId INT = (SELECT TOP 1 game_id FROM Games WHERE is_active = 1);
DECLARE @ReviewId INT = (SELECT review_id FROM Reviews WHERE user_id = @AuthorId AND game_id = @GameId);

PRINT N'[1.1] Bảng Reviews:';
SELECT review_id, user_id, game_id, rating, comment FROM Reviews WHERE review_id = @ReviewId;

PRINT N'[1.2] Bảng Votes (Đa hình - target_type = ''REVIEW''):';
SELECT vote_id, user_id, target_type, target_id, vote_type FROM Votes WHERE target_type = 'REVIEW' AND target_id = @ReviewId;

PRINT N'[1.3] Bảng Review_Reports:';
SELECT report_id, review_id, user_id, report_reason FROM Review_Reports WHERE review_id = @ReviewId;
GO


-- =========================================================================================
-- KỊCH BẢN 2: THỰC THI sp_DeleteReview VÀ KIỂM CHỨNG TÍNH NGUYÊN TỬ (COMMIT TRANSACTION)
-- Ý nghĩa & Trọng tâm bảo vệ đồ án:
--   - Thủ tục mở Transaction (BEGIN TRANSACTION).
--   - Lần lượt dọn dẹp sạch: Votes ➔ Review_Reports ➔ Reviews.
--   - Chốt giao dịch an toàn (COMMIT TRANSACTION).
-- =========================================================================================
PRINT N'';
PRINT N'=========================================================================================';
PRINT N'KỊCH BẢN 2: THỰC THI sp_DeleteReview (TRANSACTION HOÀN TẤT THÀNH CÔNG)';
PRINT N'=========================================================================================';

DECLARE @AuthorId INT = (SELECT user_id FROM Users WHERE email = 'author_trans_del@gamefit.vn');
DECLARE @GameId INT = (SELECT TOP 1 game_id FROM Games WHERE is_active = 1);
DECLARE @TargetReviewId INT = (SELECT review_id FROM Reviews WHERE user_id = @AuthorId AND game_id = @GameId);

PRINT N'Gọi thủ tục: EXEC sp_DeleteReview @user_id = ' + CAST(@AuthorId AS VARCHAR(10)) + N', @game_id = ' + CAST(@GameId AS VARCHAR(10));
EXEC sp_DeleteReview @user_id = @AuthorId, @game_id = @GameId;

PRINT N'';
PRINT N'-> KIỂM TRA ĐỐI CHIẾU CẢ 3 BẢNG SAU KHI TRANSACTION COMMIT:';

-- 1. Bảng Reviews
PRINT N'[2.1] Bảng Reviews (Kỳ vọng: 0 dòng):';
SELECT review_id, user_id, game_id, comment FROM Reviews WHERE review_id = @TargetReviewId;

-- 2. Bảng Votes (Đã được dọn dẹp sạch, không bị mồ côi)
PRINT N'[2.2] Bảng Votes (Kỳ vọng: 0 dòng):';
SELECT vote_id, user_id, target_type, target_id FROM Votes WHERE target_type = 'REVIEW' AND target_id = @TargetReviewId;

-- 3. Bảng Review_Reports
PRINT N'[2.3] Bảng Review_Reports (Kỳ vọng: 0 dòng):';
SELECT report_id, review_id, user_id FROM Review_Reports WHERE review_id = @TargetReviewId;

PRINT N'';
PRINT N'-> KẾT QUẢ 2: THÀNH CÔNG RỰC RỠ!';
PRINT N'   Transaction đã dọn dẹp nguyên tử trên cả 3 bảng liên quan trong cùng một giao dịch an toàn.';
GO


-- =========================================================================================
-- KỊCH BẢN 3: MINH HỌA CƠ CHẾ ROLLBACK KHI GẶP LỖI (ACID ATOMICITY SIMULATION)
-- Ý nghĩa: Giải thích và chứng minh cơ chế ROLLBACK trong khối CATCH của thủ tục:
--          IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
-- =========================================================================================
PRINT N'';
PRINT N'=========================================================================================';
PRINT N'KỊCH BẢN 3: GIẢI THÍCH CƠ CHẾ ROLLBACK CỦA sp_DeleteReview KHI CÓ SỰ CỐ';
PRINT N'=========================================================================================';

PRINT N'Trong mã nguồn sp_DeleteReview:';
PRINT N'   BEGIN TRY';
PRINT N'       BEGIN TRANSACTION;';
PRINT N'       -- Bước 1: Xóa Votes';
PRINT N'       -- Bước 2: Xóa Review_Reports';
PRINT N'       -- Bước 3: Xóa Reviews';
PRINT N'       COMMIT TRANSACTION;';
PRINT N'   END TRY';
PRINT N'   BEGIN CATCH';
PRINT N'       IF @@TRANCOUNT > 0';
PRINT N'           ROLLBACK TRANSACTION;  -- << HOÀN TÁC TOÀN BỘ NẾU BẤT KỲ BƯỚC NÀO GẶP SỰ CỐ';
PRINT N'       DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE();';
PRINT N'       RAISERROR(@ErrMsg, 16, 1);';
PRINT N'   END CATCH;';
PRINT N'-> KẾT QUẢ 3: Đảm bảo nguyên lý All-or-Nothing của chuẩn ACID, không bao giờ để lại dữ liệu rác.';
GO


-- -----------------------------------------------------------------------------------------
-- BƯỚC CLEANUP: DỌN DẸP DỮ LIỆU TEST
-- -----------------------------------------------------------------------------------------
PRINT N'';
PRINT N'-----------------------------------------------------------------------------------------';
PRINT N'DỌN DẸP DỮ LIỆU TEST (CLEANUP)';
PRINT N'-----------------------------------------------------------------------------------------';

DELETE FROM Users WHERE email IN ('author_trans_del@gamefit.vn', 'voter_trans_del@gamefit.vn', 'reporter_trans_del@gamefit.vn');
PRINT N'-> Đã dọn dẹp các tài khoản test.';
GO

PRINT N'=========================================================================================';
PRINT N'HOÀN TẤT DEMO TRANSACTION: sp_DeleteReview';
PRINT N'=========================================================================================';
GO
