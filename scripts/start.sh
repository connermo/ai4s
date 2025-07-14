#!/bin/bash

set -e

echo "=== GPU开发平台启动脚本 ==="

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 创建必要的宿主机目录
echo -e "${BLUE}检查并创建共享目录...${NC}"
mkdir -p ./data/shared-ro
mkdir -p ./data/shared-rw
mkdir -p ./data/users

# 设置权限
chmod 755 ./data
chmod 755 ./data/shared-ro
chmod 777 ./data/shared-rw
chmod 777 ./data/users

echo -e "${GREEN}✓ 目录结构准备就绪${NC}"
echo ""

# 检查是否已构建镜像
if ! docker images | grep -q "connermo/ai4s-env"; then
    echo -e "${YELLOW}警告: 开发环境镜像(connermo/ai4s-env)未找到，请先执行 ./scripts/build.sh ${NC}"
    exit 1
fi

# 启动平台后端
echo "启动平台管理后端..."
docker compose up -d ai4s-platform

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ 平台后端启动成功${NC}"
else
    echo -e "${RED}✗ 平台后端启动失败${NC}"
    exit 1
fi

# 等待服务启动
echo "等待服务启动..."
sleep 5

# 检查服务状态
if curl -s http://localhost:8080/api/users > /dev/null; then
    echo -e "${GREEN}✓ 平台API服务正常${NC}"
else
    echo -e "${YELLOW}警告: API服务可能还在启动中...${NC}"
fi

echo -e "${GREEN}=== 启动完成 ===${NC}"
echo ""
echo -e "${BLUE}平台访问地址:${NC}"
echo "  管理界面: http://localhost:8080"
echo "  API接口: http://localhost:8080/api"
echo ""
echo -e "${BLUE}默认管理员账号:${NC}"
echo "  用户名: admin"
echo "  密码: admin123"
echo ""
echo -e "${BLUE}查看日志:${NC}"
echo "  docker compose logs -f ai4s-platform"
echo ""
echo -e "${BLUE}停止服务:${NC}"
echo "  ./scripts/stop.sh"