-- 数据库初始化脚本
-- 创建用户表
CREATE TABLE IF NOT EXISTS users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    email VARCHAR(100),
    is_active BOOLEAN DEFAULT TRUE,
    is_admin BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    container_id VARCHAR(64),
    base_port INT UNIQUE,
    last_login TIMESTAMP NULL
);

-- 创建容器表
CREATE TABLE IF NOT EXISTS containers (
    id VARCHAR(64) PRIMARY KEY,
    user_id INT NOT NULL,
    name VARCHAR(100) NOT NULL,
    status VARCHAR(20) DEFAULT 'stopped',
    image_name VARCHAR(200) DEFAULT 'connermo/ai4s-env:latest',
    cpu_limit VARCHAR(20) DEFAULT '2',
    memory_limit VARCHAR(20) DEFAULT '4g',
    gpu_devices VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    last_seen TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
);

-- 创建容器统计表
CREATE TABLE IF NOT EXISTS container_stats (
    id INT AUTO_INCREMENT PRIMARY KEY,
    container_id VARCHAR(64) NOT NULL,
    cpu_usage DECIMAL(5,2) DEFAULT 0,
    memory_usage BIGINT DEFAULT 0,
    gpu_usage DECIMAL(5,2) DEFAULT 0,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (container_id) REFERENCES containers (id) ON DELETE CASCADE
);

-- 创建初始化状态表
CREATE TABLE IF NOT EXISTS db_init_status (
    id INT AUTO_INCREMENT PRIMARY KEY,
    component VARCHAR(50) UNIQUE NOT NULL,
    initialized BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 插入默认管理员用户 (密码: admin123)
INSERT IGNORE INTO users (username, password, email, is_admin, base_port) 
VALUES ('admin', '$2a$10$7kCbgG3FCL5wfatLw7RnL.qefBo7t1OwiGxfWma3vGHZSkYy67k12', 'admin@example.com', TRUE, 9001);

-- 标记基础数据已初始化
INSERT IGNORE INTO db_init_status (component, initialized) VALUES ('base_data', TRUE);