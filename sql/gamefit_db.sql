CREATE DATABASE gamefit_db;
GO

USE gamefit_db;
GO

-- 1. Bảng Users
CREATE TABLE Users (
    user_id INT IDENTITY(1,1) PRIMARY KEY,
    user_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    role VARCHAR(20) DEFAULT 'User', -- Admin 
    create_at DATETIME DEFAULT GETDATE(),
    status VARCHAR(20) DEFAULT 'Active', -- Locked 
    lock_until DATETIME,
    lock_reason NVARCHAR(255)
);

-- 2. Bảng Cpus
CREATE TABLE Cpus (
    cpu_id INT IDENTITY(1,1) PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    brand VARCHAR(50) NOT NULL,
    benchmark_score INT NOT NULL
);

-- 3. Bảng Gpus
CREATE TABLE Gpus (
    gpu_id INT IDENTITY(1,1) PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    brand VARCHAR(50) NOT NULL,
    benchmark_score INT NOT NULL
);

-- 4. Bảng Tags
CREATE TABLE Tags (
    tag_id INT IDENTITY(1,1) PRIMARY KEY,
    name NVARCHAR(50) UNIQUE NOT NULL,
    is_hidden BIT NOT NULL
);

-- 5. Bảng Games
CREATE TABLE Games (
    game_id INT IDENTITY(1,1) PRIMARY KEY,
    name NVARCHAR(255) NOT NULL,
    description NVARCHAR(MAX),
    publisher NVARCHAR(100),
    developer NVARCHAR(100),
    platform VARCHAR(100),
    release_date DATE,
    image VARCHAR(255),
    trailer_url VARCHAR(MAX),
    is_active BIT DEFAULT 1, -- 1: còn hoạt động, 0: không còn hoạt động
    download_url VARCHAR(255)
);

-- 6. Bảng Games_Tags
CREATE TABLE Games_Tags (
    game_id INT NOT NULL,
    tag_id INT NOT NULL,
    CONSTRAINT PK_Games_Tags PRIMARY KEY (game_id, tag_id),
    CONSTRAINT FK_GT_Games FOREIGN KEY (game_id) REFERENCES Games(game_id),
    CONSTRAINT FK_GT_Tags FOREIGN KEY (tag_id) REFERENCES Tags(tag_id)
);

-- 7. Bảng Game_requirement
CREATE TABLE Game_requirement (
    game_id INT NOT NULL,
    type VARCHAR(20) NOT NULL CHECK(type IN('MINIMUM', 'RECOMMENDED')),
    cpu_id INT NOT NULL,
    gpu_id INT NOT NULL,
    os VARCHAR(50),
    ram INT NOT NULL,
    storage INT NOT NULL,

    CONSTRAINT PK_Game_Requirement PRIMARY KEY (game_id, type),
    CONSTRAINT FK_GR_Games FOREIGN KEY (game_id) REFERENCES Games(game_id),
    CONSTRAINT FK_GR_Cpus FOREIGN KEY (cpu_id) REFERENCES Cpus(cpu_id),
    CONSTRAINT FK_GR_Gpus FOREIGN KEY (gpu_id) REFERENCES Gpus(gpu_id)
);

-- 8. Bảng User_pc
CREATE TABLE User_pc (
    pc_id INT IDENTITY(1,1) PRIMARY KEY,
    pc_name NVARCHAR(255) NOT NULL,
    user_id INT NOT NULL,
    cpu_id INT NOT NULL,
    gpu_id INT NOT NULL,
    os VARCHAR(50) NOT NULL,
    ram INT NOT NULL,
    storage INT NOT NULL,
    is_deleted BIT DEFAULT 0

    CONSTRAINT FK_UserPc_Users FOREIGN KEY (user_id) REFERENCES Users(user_id),
    CONSTRAINT FK_UserPc_Cpus FOREIGN KEY (cpu_id) REFERENCES Cpus(cpu_id),
    CONSTRAINT FK_UserPc_Gpus FOREIGN KEY (gpu_id) REFERENCES Gpus(gpu_id)
);

-- 9. Bảng Reviews
CREATE TABLE Reviews (
    review_id INT IDENTITY(1,1) PRIMARY KEY,
    user_id INT NOT NULL,
    game_id INT NOT NULL,
    rating INT CHECK (rating >= 1 AND rating <= 5),
    comment NVARCHAR(MAX),
    created_at DATETIME DEFAULT GETDATE(),
    is_hidden BIT DEFAULT 0,
    report_status VARCHAR(20) NOT NULL DEFAULT 'NONE',

    CONSTRAINT FK_Reviews_Users FOREIGN KEY (user_id) REFERENCES Users(user_id),
    CONSTRAINT FK_Reviews_Games FOREIGN KEY (game_id) REFERENCES Games(game_id),
    CONSTRAINT UQ_User_Game_Review UNIQUE (user_id, game_id),
    CONSTRAINT CK_Reviews_ReportStatus CHECK (report_status IN ('NONE', 'PENDING', 'DISMISSED', 'HIDDEN'))
);

-- 10. Bảng Wishlist
CREATE TABLE Wishlist (
    user_id INT NOT NULL,
    game_id INT NOT NULL,
    added_at DATETIME DEFAULT GETDATE(),
    CONSTRAINT PK_Wishlist PRIMARY KEY (user_id, game_id),
    CONSTRAINT FK_Wishlist_Users FOREIGN KEY (user_id) REFERENCES Users(user_id),
    CONSTRAINT FK_Wishlist_Games FOREIGN KEY (game_id) REFERENCES Games(game_id)
);
GO

-- 11.Bảng Game_PC_Recommendation 
CREATE TABLE Game_PC_Recommendation (
    recommendation_id INT IDENTITY(1,1) PRIMARY KEY,
    user_id INT NOT NULL,      -- Ai đề xuất?
    game_id INT NOT NULL,      -- Cho tựa game nào?
    pc_id INT NOT NULL,        -- Dàn máy nào?
    type VARCHAR(20) NOT NULL CHECK(type IN('MINIMUM', 'RECOMMENDED')),
    note NVARCHAR(500) NULL,
    created_at DATETIME DEFAULT GETDATE(),
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'APPROVED', 'REJECTED', 'REPLACED')),
    reviewed_by INT NULL,
    reviewed_at DATETIME NULL,
    reject_reason NVARCHAR(500) NULL,
    CONSTRAINT FK_GamePCRec_Users FOREIGN KEY (user_id) REFERENCES Users(user_id),
    CONSTRAINT FK_GamePCRec_Admin FOREIGN KEY (reviewed_by) REFERENCES Users(user_id),
    CONSTRAINT FK_GamePCRec_Games FOREIGN KEY (game_id) REFERENCES Games(game_id),
    CONSTRAINT FK_GamePCRec_UserPc FOREIGN KEY (pc_id) REFERENCES User_pc(pc_id),

    CONSTRAINT UQ_GamePCRec_Unique_PC UNIQUE (user_id, game_id, pc_id)
);


-- 12. Bảng Votes 
CREATE TABLE Votes (
    vote_id INT IDENTITY(1,1) PRIMARY KEY,
    user_id INT NOT NULL,
    target_type VARCHAR(20) NOT NULL CHECK (target_type IN ('REVIEW', 'RECOMMENDATION')), 
    target_id INT NOT NULL,  -- Lưu review_id hoặc recommendation_id
    vote_type SMALLINT NOT NULL CHECK (vote_type IN (1, -1)),
    created_at DATETIME DEFAULT GETDATE(),

    -- Khóa ngoại duy nhất là user_id
    CONSTRAINT FK_Votes_Users FOREIGN KEY (user_id) REFERENCES Users(user_id),
    
    -- Chống User vote 1 mục nhiều lần
    CONSTRAINT UQ_Votes_User_Target UNIQUE (user_id, target_type, target_id)
);
GO

-- 13. Bảng Review_Reports
CREATE TABLE Review_Reports (
    report_id INT IDENTITY(1,1) PRIMARY KEY,
    review_id INT NOT NULL, 
    user_id INT NOT NULL,
    report_reason NVARCHAR(255) NOT NULL,
    report_detail NVARCHAR(500) NULL,
    reported_at DATETIME DEFAULT DATEADD(HOUR, 7, GETUTCDATE()),

    CONSTRAINT FK_ReviewReports_Reviews FOREIGN KEY (review_id) REFERENCES Reviews(review_id) ON DELETE CASCADE,
    CONSTRAINT FK_ReviewReports_Users FOREIGN KEY (user_id) REFERENCES Users(user_id),
    CONSTRAINT UQ_ReviewReports_User_Review UNIQUE (user_id, review_id) -- 1 User chỉ được báo cáo 1 Review 1 lần
);
GO

-- 14. Bảng Notifications (Hộp thư thông báo người dùng)
CREATE TABLE Notifications (
    notification_id INT IDENTITY(1,1) PRIMARY KEY,
    user_id INT NOT NULL,
    title NVARCHAR(150) NOT NULL,
    message NVARCHAR(500) NOT NULL,
    type VARCHAR(30) NOT NULL DEFAULT 'SYSTEM',      -- REVIEW_HIDDEN, REPORT_RESULT, SYSTEM
    target_url VARCHAR(255) NULL,
    is_read BIT NOT NULL DEFAULT 0,                   -- 0: Chưa đọc, 1: Đã đọc
    created_at DATETIME DEFAULT DATEADD(HOUR, 7, GETUTCDATE()),

    CONSTRAINT FK_Notifications_Users FOREIGN KEY (user_id) REFERENCES Users(user_id) ON DELETE CASCADE
);
GO






  






