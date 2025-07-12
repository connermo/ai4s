-- 索引创建脚本
-- 注意：这些语句可能在重复运行时失败，应该被忽略

-- 用户表索引
CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_users_base_port ON users(base_port);

-- 容器表索引
CREATE INDEX idx_containers_user_id ON containers(user_id);
CREATE INDEX idx_containers_status ON containers(status);

-- 容器统计表索引
CREATE INDEX idx_container_stats_container_id ON container_stats(container_id);
CREATE INDEX idx_container_stats_timestamp ON container_stats(timestamp);