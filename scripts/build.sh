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
if ! command -v docker-compose &> /dev/null; then
    echo -e "${RED}错误: Docker Compose未安装${NC}"
    exit 1
fi

# 检查NVIDIA Docker运行时
if ! docker info | grep -q nvidia; then
    echo -e "${YELLOW}警告: 未检测到NVIDIA Docker运行时，GPU功能可能不可用${NC}"
fi

echo -e "${GREEN}✓ 环境检查通过${NC}"

# 创建必要的目录
echo "创建必要的目录..."
mkdir -p users shared workspace logs
chmod 755 users shared workspace logs

echo -e "${GREEN}✓ 目录创建完成${NC}"

# 构建开发环境镜像
echo "构建GPU开发环境镜像..."
docker build -t gpu-dev-env:latest -f docker/Dockerfile.dev docker/

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ 开发环境镜像构建成功${NC}"
else
    echo -e "${RED}✗ 开发环境镜像构建失败${NC}"
    exit 1
fi

# 构建平台后端
echo "构建平台管理后端..."
docker-compose build platform-backend

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
echo "  docker-compose up -d platform-backend"