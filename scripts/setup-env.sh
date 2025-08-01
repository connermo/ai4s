#!/bin/bash

echo "=== 自动设置环境变量脚本 ==="

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 获取当前工作目录的绝对路径
CURRENT_DIR=$(pwd)
echo -e "${BLUE}当前工作目录: $CURRENT_DIR${NC}"

# 检查.env文件是否存在
if [ ! -f ".env" ]; then
    echo -e "${RED}错误: .env文件不存在${NC}"
    echo "请确保在项目根目录下运行此脚本"
    exit 1
fi

# 备份原始.env文件
cp .env .env.backup.$(date +%Y%m%d_%H%M%S)
echo -e "${GREEN}✓ 已备份原始.env文件${NC}"

# 更新环境变量配置
echo -e "${BLUE}更新环境变量配置...${NC}"

# 使用sed命令更新路径配置
sed -i "s|HOST_USERS_PATH=.*|HOST_USERS_PATH=$CURRENT_DIR/data/users|g" .env
sed -i "s|HOST_SHARED_RO_PATH=.*|HOST_SHARED_RO_PATH=$CURRENT_DIR/data/shared-ro|g" .env
sed -i "s|HOST_SHARED_RW_PATH=.*|HOST_SHARED_RW_PATH=$CURRENT_DIR/data/shared-rw|g" .env
sed -i "s|HOST_GROUPS_PATH=.*|HOST_GROUPS_PATH=$CURRENT_DIR/data/groups|g" .env

echo -e "${GREEN}✓ 环境变量配置已更新${NC}"

# 验证配置
echo -e "${BLUE}验证配置...${NC}"
echo "HOST_USERS_PATH: $(grep HOST_USERS_PATH .env | cut -d'=' -f2)"
echo "HOST_SHARED_RO_PATH: $(grep HOST_SHARED_RO_PATH .env | cut -d'=' -f2)"
echo "HOST_SHARED_RW_PATH: $(grep HOST_SHARED_RW_PATH .env | cut -d'=' -f2)"
echo "HOST_GROUPS_PATH: $(grep HOST_GROUPS_PATH .env | cut -d'=' -f2)"

# 检查目录是否存在
echo -e "${BLUE}检查目录结构...${NC}"
for dir in "data/users" "data/shared-ro" "data/shared-rw" "data/groups"; do
    if [ -d "$dir" ]; then
        echo -e "${GREEN}✓ $dir 目录存在${NC}"
    else
        echo -e "${YELLOW}⚠ $dir 目录不存在，正在创建...${NC}"
        mkdir -p "$dir"
        chmod 755 "$dir"
    fi
done

# 设置目录权限
echo -e "${BLUE}设置目录权限...${NC}"
chmod 755 data/users data/shared-ro data/shared-rw data/groups
chmod 777 data/shared-rw  # 共享读写目录需要写权限

echo -e "${GREEN}=== 环境变量配置完成 ===${NC}"
echo ""
echo -e "${BLUE}下一步操作:${NC}"
echo "1. 重启管理后端服务:"
echo "   docker compose restart ai4s-platform"
echo ""
echo "2. 运行测试脚本验证配置:"
echo "   ./tests/test-user-mount.sh"
echo ""
echo -e "${YELLOW}注意: 如果之前有容器启动失败，请先清理失败的容器${NC}"
echo "   docker ps -a | grep 'Exited' | awk '{print \$1}' | xargs docker rm" 