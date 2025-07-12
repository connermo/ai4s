#!/bin/bash

echo "=== GPU开发平台停止脚本 ==="

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 停止所有用户容器
echo "停止所有用户开发容器..."
USER_CONTAINERS=$(docker ps -q --filter "name=dev-*")
if [ ! -z "$USER_CONTAINERS" ]; then
    docker stop $USER_CONTAINERS
    echo -e "${GREEN}✓ 用户容器已停止${NC}"
else
    echo -e "${YELLOW}没有运行中的用户容器${NC}"
fi

# 停止平台后端
echo "停止平台管理后端..."
docker-compose down

echo -e "${GREEN}✓ 平台后端已停止${NC}"

echo -e "${GREEN}=== 停止完成 ===${NC}"
echo ""
echo "如需完全清理，可以运行:"
echo "  ./scripts/cleanup.sh"