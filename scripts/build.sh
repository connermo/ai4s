#!/bin/bash

set -e

echo "=== GPU开发平台构建脚本 ==="

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检查Docker是否安装
if ! command -v docker &> /dev/null; then
    echo -e "${RED}错误: Docker未安装${NC}"
    exit 1
fi

# 检查Docker Compose是否安装
if ! docker compose version &> /dev/null; then
    echo -e "${RED}错误: Docker Compose未安装或版本过低${NC}"
    exit 1
fi

# GPU支持说明
echo "注意: 此平台需要NVIDIA GPU和Container Toolkit支持"

echo -e "${GREEN}✓ 环境检查通过${NC}"

# 创建必要的目录
echo "创建必要的目录..."

# 从.env文件读取路径配置（如果存在）
if [ -f .env ]; then
    source .env
fi

# 宿主机目录配置
HOST_USERS_PATH=${HOST_USERS_PATH:-./data/users}
HOST_SHARED_RO_PATH=${HOST_SHARED_RO_PATH:-./data/shared-ro}
HOST_SHARED_RW_PATH=${HOST_SHARED_RW_PATH:-./data/shared-rw}

# 确保这些目录存在
mkdir -p "$HOST_USERS_PATH"
mkdir -p "$HOST_SHARED_RO_PATH"
mkdir -p "$HOST_SHARED_RW_PATH"
mkdir -p logs

# 设置权限
chmod 755 "$HOST_SHARED_RO_PATH"
chmod 777 "$HOST_SHARED_RW_PATH"
chmod 777 "$HOST_USERS_PATH"
chmod 777 logs


echo "创建的目录:"
echo "  用户数据: $HOST_USERS_PATH"
echo "  只读共享: $HOST_SHARED_RO_PATH"
echo "  读写共享: $HOST_SHARED_RW_PATH"
echo "  日志目录: ./logs"

echo -e "${GREEN}✓ 目录创建完成${NC}"

# 构建开发环境镜像
echo "构建GPU开发环境镜像..."
docker build -t connermo/ai4s-env:latest -f docker/Dockerfile.dev .

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ 开发环境镜像构建成功${NC}"
else
    echo -e "${RED}✗ 开发环境镜像构建失败${NC}"
    exit 1
fi

# 构建平台后端
echo "构建平台管理后端..."
docker compose build ai4s-platform

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ 平台后端构建成功${NC}"
else
    echo -e "${RED}✗ 平台后端构建失败${NC}"
    exit 1
fi

echo -e "${GREEN}=== 构建完成 ===${NC}"
echo ""
echo "使用以下命令启动平台:"
echo "  ./scripts/start.sh"
echo ""
echo "或者手动启动:"
echo "  docker compose up -d ai4s-platform"