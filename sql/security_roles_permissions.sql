-- =========================================================================================
-- FILE: security_roles_permissions.sql
-- MỤC ĐÍCH: THIẾT LẬP BẢO MẬT VÀ PHÂN QUYỀN TRUY CẬP (ROLE / USER) TRÊN SQL SERVER CHO GAMEFIT
-- ÁP DỤNG CHO: CHƯƠNG 4 - QUẢN LÝ GIAO DỊCH & BẢO MẬT (ĐỒ ÁN / BÁO CÁO TỐT NGHIỆP)
-- HỆ THỐNG GỒM 4 VAI TRÒ: 
--   1. Role_Admin      : Quản trị viên tối cao (Quản lý toàn bộ hệ thống, Games, Users)
--   2. Role_Moderator  : Kiểm duyệt viên (Quản lý Reviews, Reports, Duyệt đề xuất cấu hình)
--   3. Role_User       : Thành viên chính thức (Viết đánh giá, lưu dàn máy, wishlist, vote)
--   4. Role_Guest      : Khách vãng lai (Chỉ xem và tra cứu công khai qua View/Function)
-- =========================================================================================

USE master;
GO

-- -----------------------------------------------------------------------------------------
-- 1. TẠO SERVER LOGINS (Định danh đăng nhập cấp máy chủ SQL Server)
-- -----------------------------------------------------------------------------------------
-- 1.1. Login dành cho Quản trị viên hệ thống (Admin)
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'login_gamefit_admin')
BEGIN
    CREATE LOGIN login_gamefit_admin WITH PASSWORD = N'Admin@GameFit2026!', CHECK_POLICY = OFF;
END
GO

-- 1.2. Login dành cho Kiểm duyệt viên cộng đồng (Moderator)
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'login_gamefit_mod')
BEGIN
    CREATE LOGIN login_gamefit_mod WITH PASSWORD = N'Mod@GameFit2026!', CHECK_POLICY = OFF;
END
GO

-- 1.3. Login dành cho Thành viên hệ thống (User đã đăng nhập)
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'login_gamefit_user')
BEGIN
    CREATE LOGIN login_gamefit_user WITH PASSWORD = N'User@GameFit2026!', CHECK_POLICY = OFF;
END
GO

-- 1.4. Login dành cho Khách vãng lai (Guest / Chưa đăng nhập)
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'login_gamefit_guest')
BEGIN
    CREATE LOGIN login_gamefit_guest WITH PASSWORD = N'Guest@GameFit2026!', CHECK_POLICY = OFF;
END
GO

-- -----------------------------------------------------------------------------------------
-- 2. TẠO DATABASE USERS TRONG CSDL gamefit_db
-- -----------------------------------------------------------------------------------------
USE gamefit_db;
GO

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'usr_admin')
BEGIN
    CREATE USER usr_admin FOR LOGIN login_gamefit_admin;
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'usr_mod')
BEGIN
    CREATE USER usr_mod FOR LOGIN login_gamefit_mod;
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'usr_user')
BEGIN
    CREATE USER usr_user FOR LOGIN login_gamefit_user;
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'usr_guest')
BEGIN
    CREATE USER usr_guest FOR LOGIN login_gamefit_guest;
END
GO

-- -----------------------------------------------------------------------------------------
-- 3. TẠO DATABASE ROLES (Nhóm vai trò bảo mật nghiệp vụ)
-- -----------------------------------------------------------------------------------------
-- Role 1: Quản trị viên (Toàn quyền quản lý game, phần cứng, tài khoản, thống kê)
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'Role_Admin' AND type = 'R')
BEGIN
    CREATE ROLE Role_Admin;
END
GO

-- Role 2: Kiểm duyệt viên (Quản lý và xử lý vi phạm Reviews, Review_Reports, Duyệt PC Recommendation)
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'Role_Moderator' AND type = 'R')
BEGIN
    CREATE ROLE Role_Moderator;
END
GO

-- Role 3: Thành viên (Tương tác review cá nhân, lưu cấu hình PC, wishlist, vote, báo cáo vi phạm)
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'Role_User' AND type = 'R')
BEGIN
    CREATE ROLE Role_User;
END
GO

-- Role 4: Khách vãng lai (Chỉ xem danh mục game, cấu hình benchmark, tìm kiếm qua Views)
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'Role_Guest' AND type = 'R')
BEGIN
    CREATE ROLE Role_Guest;
END
GO

-- Gán Database Users vào các Role tương ứng
ALTER ROLE Role_Admin ADD MEMBER usr_admin;
ALTER ROLE Role_Moderator ADD MEMBER usr_mod;
ALTER ROLE Role_User ADD MEMBER usr_user;
ALTER ROLE Role_Guest ADD MEMBER usr_guest;
GO

-- -----------------------------------------------------------------------------------------
-- 4. THIẾT LẬP QUYỀN TRUY CẬP (GRANT / DENY) THEO NGUYÊN TẮC ĐẶC QUYỀN TỐI THIỂU
-- -----------------------------------------------------------------------------------------

-- =========================================================================================
-- A. PHÂN QUYỀN CHO Role_Guest (Khách vãng lai - Chỉ Đọc)
-- =========================================================================================
-- 1. Cấp quyền SELECT trên các View công khai
GRANT SELECT ON vw_Game_Card TO Role_Guest;
GRANT SELECT ON vw_Cpu_Detail TO Role_Guest;
GRANT SELECT ON vw_Gpu_Detail TO Role_Guest;

-- 2. Cấp quyền SELECT trên bảng danh mục không nhạy cảm
GRANT SELECT ON Tags TO Role_Guest;
GRANT SELECT ON Cpus TO Role_Guest;
GRANT SELECT ON Gpus TO Role_Guest;
GRANT SELECT ON Game_requirement TO Role_Guest;

-- 3. Cấp quyền thực thi các Stored Procedure / Function tra cứu công khai
IF OBJECT_ID('sp_getGames') IS NOT NULL GRANT EXECUTE ON sp_getGames TO Role_Guest;
IF OBJECT_ID('sp_getGameDetail') IS NOT NULL GRANT EXECUTE ON sp_getGameDetail TO Role_Guest;
IF OBJECT_ID('sp_sortGames') IS NOT NULL GRANT EXECUTE ON sp_sortGames TO Role_Guest;
IF OBJECT_ID('fn_getReviews') IS NOT NULL GRANT SELECT ON fn_getReviews TO Role_Guest;

-- 4. Chặn hoàn toàn mọi quyền thao tác ghi dữ liệu (INSERT, UPDATE, DELETE)
DENY INSERT, UPDATE, DELETE ON SCHEMA::dbo TO Role_Guest;
-- Cấm tuyệt đối xem thông tin người dùng và tài khoản
DENY SELECT ON Users TO Role_Guest;
GO

-- =========================================================================================
-- B. PHÂN QUYỀN CHO Role_User (Thành viên hệ thống)
-- =========================================================================================
-- 1. Kế thừa toàn bộ quyền ĐỌC của Role_Guest
GRANT SELECT ON vw_Game_Card TO Role_User;
GRANT SELECT ON vw_Cpu_Detail TO Role_User;
GRANT SELECT ON vw_Gpu_Detail TO Role_User;
GRANT SELECT ON vw_User_Safe_Profile TO Role_User;
GRANT SELECT ON Tags TO Role_User;
GRANT SELECT ON Cpus TO Role_User;
GRANT SELECT ON Gpus TO Role_User;
GRANT SELECT ON Game_requirement TO Role_User;

-- 2. Quyền thao tác trực tiếp trên các bảng dữ liệu cá nhân
GRANT SELECT, INSERT, UPDATE, DELETE ON User_pc TO Role_User;
GRANT SELECT, INSERT, DELETE ON Wishlist TO Role_User;
GRANT SELECT, INSERT, UPDATE, DELETE ON Votes TO Role_User;
GRANT SELECT, INSERT ON Review_Reports TO Role_User;
GRANT SELECT, UPDATE ON Notifications TO Role_User;

-- 3. Cấp quyền EXECUTE các Stored Procedure nghiệp vụ tương tác
IF OBJECT_ID('sp_AddReview') IS NOT NULL GRANT EXECUTE ON sp_AddReview TO Role_User;
IF OBJECT_ID('sp_EditReview') IS NOT NULL GRANT EXECUTE ON sp_EditReview TO Role_User;
IF OBJECT_ID('sp_DeleteReview') IS NOT NULL GRANT EXECUTE ON sp_DeleteReview TO Role_User;
IF OBJECT_ID('sp_ReportReview') IS NOT NULL GRANT EXECUTE ON sp_ReportReview TO Role_User;
IF OBJECT_ID('sp_AddComputerConfig') IS NOT NULL GRANT EXECUTE ON sp_AddComputerConfig TO Role_User;
IF OBJECT_ID('sp_UpdateComputerConfig') IS NOT NULL GRANT EXECUTE ON sp_UpdateComputerConfig TO Role_User;
IF OBJECT_ID('sp_DeleteComputerConfig') IS NOT NULL GRANT EXECUTE ON sp_DeleteComputerConfig TO Role_User;
IF OBJECT_ID('sp_SubmitPCRecommendation') IS NOT NULL GRANT EXECUTE ON sp_SubmitPCRecommendation TO Role_User;
IF OBJECT_ID('sp_Vote') IS NOT NULL GRANT EXECUTE ON sp_Vote TO Role_User;

-- 4. BẢO MẬT: Chặn quyền quản trị và các trường dữ liệu nhạy cảm
DENY INSERT, UPDATE, DELETE ON Games TO Role_User;
DENY INSERT, UPDATE, DELETE ON Tags TO Role_User;
DENY INSERT, UPDATE, DELETE ON Cpus TO Role_User;
DENY INSERT, UPDATE, DELETE ON Gpus TO Role_User;
DENY INSERT, UPDATE, DELETE ON Game_requirement TO Role_User;

DENY SELECT ON Users(password) TO Role_User;
DENY UPDATE ON Users(role) TO Role_User;

-- Chặn thực thi các SP kiểm duyệt của Admin & Mod
IF OBJECT_ID('sp_ModerateReview') IS NOT NULL DENY EXECUTE ON sp_ModerateReview TO Role_User;
IF OBJECT_ID('sp_ApproveRecommendation') IS NOT NULL DENY EXECUTE ON sp_ApproveRecommendation TO Role_User;
IF OBJECT_ID('sp_RejectRecommendation') IS NOT NULL DENY EXECUTE ON sp_RejectRecommendation TO Role_User;
IF OBJECT_ID('sp_addGame') IS NOT NULL DENY EXECUTE ON sp_addGame TO Role_User;
IF OBJECT_ID('sp_deleteGame') IS NOT NULL DENY EXECUTE ON sp_deleteGame TO Role_User;
GO

-- =========================================================================================
-- C. PHÂN QUYỀN CHO Role_Moderator (Kiểm duyệt viên nội dung & cộng đồng)
-- =========================================================================================
-- 1. Quyền đọc thông tin hệ thống (Views và danh mục)
GRANT SELECT ON vw_Game_Card TO Role_Moderator;
GRANT SELECT ON vw_Cpu_Detail TO Role_Moderator;
GRANT SELECT ON vw_Gpu_Detail TO Role_Moderator;
GRANT SELECT ON vw_User_Safe_Profile TO Role_Moderator;
GRANT SELECT ON Games TO Role_Moderator;
GRANT SELECT ON Tags TO Role_Moderator;
GRANT SELECT ON Cpus TO Role_Moderator;
GRANT SELECT ON Gpus TO Role_Moderator;
GRANT SELECT ON Game_requirement TO Role_Moderator;
GRANT SELECT ON User_pc TO Role_Moderator;
GRANT SELECT ON Votes TO Role_Moderator;

-- 2. ĐẶC QUYỀN KIỂM DUYỆT: Toàn quyền thao tác trên Reviews và Báo cáo vi phạm
GRANT SELECT, UPDATE, DELETE ON Reviews TO Role_Moderator;
GRANT SELECT, UPDATE, DELETE ON Review_Reports TO Role_Moderator;
GRANT SELECT, INSERT, UPDATE, DELETE ON Notifications TO Role_Moderator;
GRANT SELECT, UPDATE ON Game_PC_Recommendation TO Role_Moderator;

-- 3. Cấp quyền thực thi các Stored Procedure phục vụ kiểm duyệt và xử lý vi phạm
IF OBJECT_ID('sp_GetReportedReviews') IS NOT NULL GRANT EXECUTE ON sp_GetReportedReviews TO Role_Moderator;
IF OBJECT_ID('sp_GetReviewReportDetails') IS NOT NULL GRANT EXECUTE ON sp_GetReviewReportDetails TO Role_Moderator;
IF OBJECT_ID('sp_ModerateReview') IS NOT NULL GRANT EXECUTE ON sp_ModerateReview TO Role_Moderator;
IF OBJECT_ID('sp_DeleteReview') IS NOT NULL GRANT EXECUTE ON sp_DeleteReview TO Role_Moderator;
IF OBJECT_ID('sp_Admin_GetGamePCRecommendations') IS NOT NULL GRANT EXECUTE ON sp_Admin_GetGamePCRecommendations TO Role_Moderator;
IF OBJECT_ID('sp_Admin_GetRecommendationDetail') IS NOT NULL GRANT EXECUTE ON sp_Admin_GetRecommendationDetail TO Role_Moderator;
IF OBJECT_ID('sp_Admin_ApproveRecommendation') IS NOT NULL GRANT EXECUTE ON sp_Admin_ApproveRecommendation TO Role_Moderator;
IF OBJECT_ID('sp_Admin_RejectRecommendation') IS NOT NULL GRANT EXECUTE ON sp_Admin_RejectRecommendation TO Role_Moderator;
IF OBJECT_ID('sp_getGames') IS NOT NULL GRANT EXECUTE ON sp_getGames TO Role_Moderator;
IF OBJECT_ID('sp_getGameDetail') IS NOT NULL GRANT EXECUTE ON sp_getGameDetail TO Role_Moderator;
IF OBJECT_ID('sp_sortGames') IS NOT NULL GRANT EXECUTE ON sp_sortGames TO Role_Moderator;

-- 4. BẢO MẬT ĐỐI VỚI KIỂM DUYỆT VIÊN:
-- Không được phép Thêm / Xóa / Sửa danh mục trò chơi gốc
DENY INSERT, UPDATE, DELETE ON Games TO Role_Moderator;
DENY INSERT, UPDATE, DELETE ON Tags TO Role_Moderator;
DENY INSERT, UPDATE, DELETE ON Cpus TO Role_Moderator;
DENY INSERT, UPDATE, DELETE ON Gpus TO Role_Moderator;
DENY INSERT, UPDATE, DELETE ON Game_requirement TO Role_Moderator;

-- Không được phép can thiệp bảng Users (Xem mật khẩu, đổi role, xóa tài khoản)
DENY SELECT ON Users(password) TO Role_Moderator;
DENY INSERT, UPDATE, DELETE ON Users TO Role_Moderator;

-- Chặn thực thi các SP thuộc quyền quản trị tối cao của Admin
IF OBJECT_ID('sp_addGame') IS NOT NULL DENY EXECUTE ON sp_addGame TO Role_Moderator;
IF OBJECT_ID('sp_deleteGame') IS NOT NULL DENY EXECUTE ON sp_deleteGame TO Role_Moderator;
IF OBJECT_ID('sp_AdminAddUser') IS NOT NULL DENY EXECUTE ON sp_AdminAddUser TO Role_Moderator;
IF OBJECT_ID('sp_ChangeUserRole') IS NOT NULL DENY EXECUTE ON sp_ChangeUserRole TO Role_Moderator;
GO

-- =========================================================================================
-- D. PHÂN QUYỀN CHO Role_Admin (Quản trị viên tối cao)
-- =========================================================================================
-- 1. Toàn quyền Đọc / Ghi trên toàn bộ các bảng nghiệp vụ
GRANT SELECT, INSERT, UPDATE, DELETE ON Games TO Role_Admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON Tags TO Role_Admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON Games_Tags TO Role_Admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON Game_requirement TO Role_Admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON Cpus TO Role_Admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON Gpus TO Role_Admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON Reviews TO Role_Admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON Review_Reports TO Role_Admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON Game_PC_Recommendation TO Role_Admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON Notifications TO Role_Admin;
GRANT SELECT, INSERT, UPDATE ON Users TO Role_Admin;

-- 2. Cấp quyền thực thi toàn bộ Stored Procedures quản trị và thống kê
GRANT EXECUTE ON SCHEMA::dbo TO Role_Admin;

-- 3. Bảo vệ an toàn: Chặn xóa vĩnh viễn bảng Users để chống mất mát dữ liệu
DENY DELETE ON Users TO Role_Admin;
GO

-- -----------------------------------------------------------------------------------------
-- 5. KỊCH BẢN KIỂM THỬ PHÂN QUYỀN (TEST CASES - CHỤP MÀN HÌNH BÁO CÁO)
-- -----------------------------------------------------------------------------------------

/*
-- =========================================================================================
-- TEST CASE 1: Kiểm tra quyền của Khách vãng lai (usr_guest)
-- =========================================================================================
EXECUTE AS USER = 'usr_guest';
SELECT SUSER_NAME() AS CurrentLogin, USER_NAME() AS CurrentDBUser;

-- Thao tác 1.1: Xem danh mục game qua View (Kỳ vọng: THÀNH CÔNG)
SELECT TOP 5 game_id, game_name, release_date FROM vw_Game_Card;

-- Thao tác 1.2: Cố tình truy vấn mật khẩu người dùng (Kỳ vọng: BỊ CHẶN LỖI 229)
SELECT user_id, email, password FROM Users;
-- Kết quả trả về lỗi: Msg 229: The SELECT permission was denied on the object 'Users'...

-- Thao tác 1.3: Cố tình thêm game mới (Kỳ vọng: BỊ CHẶN LỖI 229)
INSERT INTO Games(name) VALUES (N'Game Hack');
-- Kết quả trả về lỗi: Msg 229: The INSERT permission was denied on the object 'Games'...

REVERT; -- Quay lại tài khoản gốc của phiên làm việc
GO

-- =========================================================================================
-- TEST CASE 2: Kiểm tra quyền của Thành viên thường (usr_user)
-- =========================================================================================
EXECUTE AS USER = 'usr_user';

-- Thao tác 2.1: Thao tác trên cấu hình máy cá nhân (Kỳ vọng: THÀNH CÔNG)
SELECT * FROM User_pc;

-- Thao tác 2.2: Cố tình gọi Stored Procedure kiểm duyệt (Kỳ vọng: BỊ CHẶN LỖI 229)
EXEC sp_ModerateReview @review_id = 1, @action = 'HIDE';
-- Kết quả trả về lỗi: Msg 229: The EXECUTE permission was denied on the object 'sp_ModerateReview'...

-- Thao tác 2.3: Cố tình tự nâng quyền của mình lên Admin (Kỳ vọng: BỊ CHẶN)
UPDATE Users SET role = 'Admin' WHERE user_id = 1;
-- Kết quả trả về lỗi: The UPDATE permission was denied on the column 'role'...

REVERT;
GO

-- =========================================================================================
-- TEST CASE 3: Kiểm tra quyền của Kiểm duyệt viên (usr_mod)
-- =========================================================================================
EXECUTE AS USER = 'usr_mod';

-- Thao tác 3.1: Xem danh sách review bị báo cáo vi phạm (Kỳ vọng: THÀNH CÔNG)
IF OBJECT_ID('sp_GetReportedReviews') IS NOT NULL
    EXEC sp_GetReportedReviews;

-- Thao tác 3.2: Thực hiện kiểm duyệt ẩn review vi phạm (Kỳ vọng: THÀNH CÔNG)
-- (Nếu có review_id = 1 có thể chạy lệnh này)
-- EXEC sp_ModerateReview @review_id = 1, @action = 'HIDE';

-- Thao tác 3.3: Cố tình thêm hoặc xóa game gốc của hệ thống (Kỳ vọng: BỊ CHẶN LỖI 229)
INSERT INTO Games(name) VALUES (N'Game Tu Y Them');
-- Kết quả trả về lỗi: The INSERT permission was denied on the object 'Games'...

-- Thao tác 3.4: Cố tình xóa tài khoản người dùng (Kỳ vọng: BỊ CHẶN LỖI 229)
DELETE FROM Users WHERE user_id = 1;
-- Kết quả trả về lỗi: The DELETE permission was denied on the object 'Users'...

REVERT;
GO

-- =========================================================================================
-- TEST CASE 4: Kiểm tra quyền của Quản trị viên (usr_admin)
-- =========================================================================================
EXECUTE AS USER = 'usr_admin';

-- Thao tác 4.1: Gọi Stored Procedure thống kê hệ thống (Kỳ vọng: THÀNH CÔNG)
IF OBJECT_ID('sp_GetDashboardStatistics') IS NOT NULL
    EXEC sp_GetDashboardStatistics;

-- Thao tác 4.2: Quản lý danh mục game (Kỳ vọng: THÀNH CÔNG)
SELECT COUNT(*) AS TotalGames FROM Games;

REVERT;
GO
*/
