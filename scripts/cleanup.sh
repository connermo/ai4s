#!/bin/bash

echo "=== GPU开发平台清理脚本 ==="

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}警告: 此操作将删除所有容器、镜像和数据！${NC}"
read -p "确定要继续吗? (y/N): " -n 1 -r
echo

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "操作已取消"
    exit 1
fi

# 停止所有相关容器
echo "停止所有相关容器..."
docker stop $(docker ps -q --filter "name=dev-*") 2>/dev/null || true
docker stop $(docker ps -q --filter "name=gpu-platform-*") 2>/dev/null || true

# 删除所有相关容器
echo "删除所有相关容器..."
docker rm $(docker ps -aq --filter "name=dev-*") 2>/dev/null || true
docker rm $(docker ps -aq --filter "name=gpu-platform-*") 2>/dev/null || true

# 删除镜像
echo "删除相关镜像..."
docker rmi gpu-dev-env:latest 2>/dev/null || true
docker rmi gpu-dev-platform_platform-backend 2>/dev/null || true

# 删除网络
echo "删除Docker网络..."
docker network rm gpu-dev-platform_platform-network 2>/dev/null || true

# 清理数据库文件 (可选)
read -p "是否删除数据库文件? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    rm -f platform.db
    echo -e "${GREEN}✓ 数据库文件已删除${NC}"
fi

# 清理用户数据 (可选)
read -p "是否删除所有用户数据? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    rm -rf users/*
    echo -e "${GREEN}✓ 用户数据已删除${NC}"
fi

echo -e "${GREEN}=== 清理完成 ===${NC}"