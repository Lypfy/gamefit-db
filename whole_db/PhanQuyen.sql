
--- CREATE ROLE 

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
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'Role_Admin_Cpu' AND type = 'R')
BEGIN
    CREATE ROLE Role_Admin_Cpu;
END
GO

-- Role 4: Khách vãng lai (Chỉ xem danh mục game, cấu hình benchmark, tìm kiếm qua Views)
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'Role_Admin_Gpu' AND type = 'R')
BEGIN
    CREATE ROLE Role_Admin_Gpu;
END
GO


--- CREATE LOGIN 
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'admin')
BEGIN
    CREATE LOGIN login_admin WITH PASSWORD = N'Nghia@2026!';
END
GO



GRANT SELECT, INSERT ON dbo.Games TO usr_admin;

-- 1.2. Login dành cho Kiểm duyệt viên cộng đồng (Moderator)
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'moderater')
BEGIN
    CREATE LOGIN login_moderator WITH PASSWORD = N'Khang@2026!';
END
GO


-- 1.3. Login dành cho Thành viên hệ thống (User đã đăng nhập)
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'admin_cpu')
BEGIN
    CREATE LOGIN login_admin_cpu WITH PASSWORD = N'Khoi@2026!';
END
GO

-- 1.4. Login dành cho Khách vãng lai (Guest / Chưa đăng nhập)
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'admin_gpu')
BEGIN
    CREATE LOGIN login_admin_gpu WITH PASSWORD = N'Thang@2026!';
END
GO


--- CRAETE 

USE gamefit_db;
GO

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'usr_admin')
BEGIN
    CREATE USER usr_admin FOR LOGIN login_admin;
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'usr_mod')
BEGIN
    CREATE USER usr_mod FOR LOGIN login_moderator;
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'admin_cpu')
BEGIN
    CREATE USER admin_cpu FOR LOGIN login_admin_cpu;
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'admin_gpu')
BEGIN
    CREATE USER admin_gpu FOR LOGIN login_admin_gpu;
END
GO

--- CREATE ADD_ROLE_MEMBER 

ALTER ROLE Role_Admin ADD MEMBER usr_admin;
ALTER ROLE Role_Moderator ADD MEMBER usr_mod;
ALTER ROLE Role_Admin_Cpu ADD MEMBER admin_cpu
ALTER ROLE Role_Admin_Gpu ADD MEMBER admin_gpu
GO

--- PHÂN QUYỀN 
-- Role_Admin_Cpu
GRANT SELECT, INSERT, UPDATE, DELETE ON Cpus TO Role_Admin_Cpu;

-- Role_Admin_Gpu
GRANT SELECT, INSERT, UPDATE, DELETE ON Gpus TO Role_Admin_Gpu;

-- Role_Moderator
GRANT SELECT, UPDATE, DELETE ON Reviews TO Role_Moderator;
GRANT SELECT, UPDATE, DELETE ON Review_Reports TO Role_Moderator;
GRANT SELECT, INSERT, UPDATE, DELETE ON Notifications TO Role_Moderator;
GRANT SELECT, UPDATE ON Game_PC_Recommendation TO Role_Moderator;

DENY INSERT, UPDATE, DELETE ON Games TO Role_Moderator;
DENY INSERT, UPDATE, DELETE ON Tags TO Role_Moderator;
DENY INSERT, UPDATE, DELETE ON Cpus TO Role_Moderator;
DENY INSERT, UPDATE, DELETE ON Gpus TO Role_Moderator;
DENY INSERT, UPDATE, DELETE ON Game_requirement TO Role_Moderator;


-- Role_Admin
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

-- REVOKE

-- 2. Cấp quyền thực thi toàn bộ Stored Procedures quản trị và thống kê
GRANT EXECUTE ON SCHEMA::dbo TO Role_Admin;