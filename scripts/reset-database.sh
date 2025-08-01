#!/bin/bash

echo "=== 数据库重置脚本 ==="

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${YELLOW}警告: 此操作将清空所有数据库数据！${NC}"
echo -e "${YELLOW}包括: 用户、容器、组、统计信息等所有数据${NC}"
read -p "确定要继续吗? (y/N): " -n 1 -r
echo

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "操作已取消"
    exit 1
fi

# 检查MySQL容器是否运行
if ! docker ps | grep -q "gpu-platform-mysql"; then
    echo -e "${RED}错误: MySQL容器未运行，请先启动服务${NC}"
    echo "运行: docker compose up -d"
    exit 1
fi

echo -e "${BLUE}开始清空数据库...${NC}"

# 方法1: 通过MySQL命令行清空所有表数据
echo "方法1: 清空所有表数据..."
docker exec gpu-platform-mysql mysql -u platform -pplatform123 gpu_platform -e "
SET FOREIGN_KEY_CHECKS = 0;
TRUNCATE TABLE container_stats;
TRUNCATE TABLE containers;
TRUNCATE TABLE user_groups;
TRUNCATE TABLE grps;
TRUNCATE TABLE users;
TRUNCATE TABLE db_init_status;
SET FOREIGN_KEY_CHECKS = 1;
"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ 表数据清空成功${NC}"
else
    echo -e "${RED}✗ 表数据清空失败${NC}"
fi

# 方法2: 重新创建默认管理员用户
echo "方法2: 重新创建默认管理员用户..."
docker exec gpu-platform-mysql mysql -u platform -pplatform123 gpu_platform -e "
INSERT IGNORE INTO users (username, password, email, is_admin, base_port) 
VALUES ('admin', '\$2a\$10\$7kCbgG3FCL5wfatLw7RnL.qefBo7t1OwiGxfWma3vGHZSkYy67k12', 'admin@example.com', TRUE, 9001);

INSERT IGNORE INTO db_init_status (component, initialized) VALUES ('base_data', TRUE);
"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ 默认管理员用户创建成功${NC}"
else
    echo -e "${RED}✗ 默认管理员用户创建失败${NC}"
fi

# 验证数据库状态
echo -e "${BLUE}验证数据库状态...${NC}"
echo "用户表记录数:"
docker exec gpu-platform-mysql mysql -u platform -pplatform123 gpu_platform -e "SELECT COUNT(*) as user_count FROM users;"

echo "容器表记录数:"
docker exec gpu-platform-mysql mysql -u platform -pplatform123 gpu_platform -e "SELECT COUNT(*) as container_count FROM containers;"

echo "组表记录数:"
docker exec gpu-platform-mysql mysql -u platform -pplatform123 gpu_platform -e "SELECT COUNT(*) as group_count FROM grps;"

echo -e "${GREEN}=== 数据库重置完成 ===${NC}"
echo ""
echo -e "${BLUE}默认管理员账号:${NC}"
echo "  用户名: admin"
echo "  密码: admin123"
echo ""
echo -e "${BLUE}重启服务:${NC}"
echo "  docker compose restart ai4s-platform" 