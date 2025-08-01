#!/bin/bash

# 简化的环境设置脚本 - 只需要配置一个数据根目录

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== AI4S 简化环境设置 ===${NC}"
echo ""

# 获取当前目录
CURRENT_DIR=$(pwd)
echo -e "${YELLOW}当前目录: ${CURRENT_DIR}${NC}"

# 检查.env文件是否存在
if [ ! -f ".env" ]; then
    echo -e "${RED}❌ .env文件不存在，请先复制.env.example${NC}"
    exit 1
fi

# 备份.env文件
cp .env .env.backup.$(date +%Y%m%d_%H%M%S)
echo -e "${GREEN}✓ 已备份.env文件${NC}"

# 设置数据根目录
echo -e "${YELLOW}设置数据根目录为: ${CURRENT_DIR}/data${NC}"
sed -i "s|^DATA_ROOT=.*|DATA_ROOT=${CURRENT_DIR}/data|g" .env

# 创建数据目录结构
echo -e "${YELLOW}创建数据目录结构...${NC}"
mkdir -p data/{users,shared-ro,shared-rw,groups}

# 设置目录权限
echo -e "${YELLOW}设置目录权限...${NC}"
chmod 755 data
chmod 755 data/users
chmod 755 data/shared-ro
chmod 777 data/shared-rw  # 共享读写目录需要写权限
chmod 755 data/groups

echo -e "${GREEN}✓ 数据目录结构创建完成${NC}"
echo ""

# 显示最终配置
echo -e "${BLUE}=== 最终配置 ===${NC}"
echo -e "${YELLOW}数据根目录: ${CURRENT_DIR}/data${NC}"
echo -e "${YELLOW}用户目录: ${CURRENT_DIR}/data/users${NC}"
echo -e "${YELLOW}共享只读目录: ${CURRENT_DIR}/data/shared-ro${NC}"
echo -e "${YELLOW}共享读写目录: ${CURRENT_DIR}/data/shared-rw${NC}"
echo -e "${YELLOW}组目录: ${CURRENT_DIR}/data/groups${NC}"
echo ""

# 显示目录结构
echo -e "${BLUE}=== 目录结构 ===${NC}"
tree data/ 2>/dev/null || ls -la data/
echo ""

echo -e "${GREEN}✅ 环境设置完成！${NC}"
echo ""

# 检查是否要启动服务
echo -e "${BLUE}是否要启动服务？${NC}"
read -p "输入 'y' 启动服务，或按回车跳过: " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}启动服务...${NC}"
    ./scripts/start.sh
else
    echo -e "${YELLOW}现在可以运行: ./scripts/start.sh${NC}"
fi 