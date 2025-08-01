#!/bin/bash

echo "=== 完全重置数据库脚本 ==="

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${YELLOW}警告: 此操作将完全删除数据库，包括所有数据！${NC}"
echo -e "${YELLOW}这将删除MySQL数据卷，所有数据将永久丢失！${NC}"
read -p "确定要继续吗? (y/N): " -n 1 -r
echo

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "操作已取消"
    exit 1
fi

# 停止服务
echo -e "${BLUE}停止所有服务...${NC}"
docker compose down

# 删除MySQL数据卷
echo -e "${BLUE}删除MySQL数据卷...${NC}"
docker volume rm ai4s_mysql_data 2>/dev/null || echo "数据卷不存在或已被删除"

# 删除用户数据目录
echo -e "${BLUE}删除用户数据目录...${NC}"
read -p "是否删除用户数据目录? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    rm -rf data/users/*
    rm -rf data/groups/*
    echo -e "${GREEN}✓ 用户数据目录已清空${NC}"
fi
