-- 添加组管理功能
-- 迁移文件: 005_add_group_management.sql

-- 组表
CREATE TABLE IF NOT EXISTS groups (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(50) UNIQUE NOT NULL,
    description TEXT,
    gid INT UNIQUE NOT NULL,  -- Linux 组 GID，避免冲突
    created_by INT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (created_by) REFERENCES users (id)
);

-- 用户组关系表
CREATE TABLE IF NOT EXISTS user_groups (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    group_id INT NOT NULL,
    role ENUM('member', 'admin') DEFAULT 'member',
    joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY unique_user_group (user_id, group_id),
    FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
    FOREIGN KEY (group_id) REFERENCES groups (id) ON DELETE CASCADE
);

-- GID 分配跟踪表 (避免与系统 GID 冲突)
CREATE TABLE IF NOT EXISTS gid_allocation (
    gid INT PRIMARY KEY,
    allocated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    purpose VARCHAR(50) NOT NULL  -- 'group', 'user', 'system'等
);

-- 添加索引
CREATE INDEX IF NOT EXISTS idx_groups_name ON groups(name);
CREATE INDEX IF NOT EXISTS idx_groups_gid ON groups(gid);
CREATE INDEX IF NOT EXISTS idx_user_groups_user_id ON user_groups(user_id);
CREATE INDEX IF NOT EXISTS idx_user_groups_group_id ON user_groups(group_id);

-- 预分配系统常用 GID 范围 (0-999 为系统保留)
-- 1000-1999 为用户保留
-- 2000+ 为组分配
INSERT IGNORE INTO gid_allocation (gid, purpose) VALUES
-- 系统保留 GID (部分常见的)
(0, 'system'), (1, 'system'), (2, 'system'), (3, 'system'), (4, 'system'), (5, 'system'),
(10, 'system'), (12, 'system'), (20, 'system'), (21, 'system'), (22, 'system'),
(100, 'system'), (101, 'system'), (102, 'system'), (999, 'system'),
-- 用户 UID 范围保留一些常见值
(1000, 'user'), (1001, 'user');

-- 添加配置表用于跟踪 GID 分配范围
CREATE TABLE IF NOT EXISTS system_config (
    key_name VARCHAR(50) PRIMARY KEY,
    value_int INT,
    value_str VARCHAR(255),
    description TEXT
);

-- 插入 GID 分配配置
INSERT IGNORE INTO system_config (key_name, value_int, description) VALUES 
('min_group_gid', 2000, '组 GID 的最小值'),
('max_group_gid', 65535, '组 GID 的最大值'),
('min_user_uid', 1000, '用户 UID 的最小值'),
('max_user_uid', 1999, '用户 UID 的最大值');