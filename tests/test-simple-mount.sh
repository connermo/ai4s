#!/bin/bash

# 简化的挂载测试脚本

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== 简化挂载配置测试 ===${NC}"
echo ""

# 加载.env文件
if [ -f ".env" ]; then
    export $(grep -v '^#' .env | xargs)
fi

# 检查数据根目录配置
echo -e "${YELLOW}🔍 检查数据根目录配置:${NC}"
echo "DATA_ROOT: ${DATA_ROOT:-未设置}"
echo ""

# 检查宿主机目录结构
echo -e "${YELLOW}📁 检查宿主机目录结构:${NC}"
if [ -n "$DATA_ROOT" ]; then
    echo "数据根目录: $DATA_ROOT"
    ls -la "$DATA_ROOT" 2>/dev/null | sed 's/^/  /' || echo "  ❌ 目录不存在"
    
    echo ""
    echo "子目录检查:"
    for subdir in users shared-ro shared-rw groups; do
        if [ -d "$DATA_ROOT/$subdir" ]; then
            echo -e "  ${GREEN}✓ $subdir${NC}"
        else
            echo -e "  ${RED}❌ $subdir${NC}"
        fi
    done
else
    echo -e "${RED}❌ DATA_ROOT未设置${NC}"
fi
echo ""

# 检查Docker Compose挂载配置
echo -e "${YELLOW}🐳 检查Docker Compose挂载配置:${NC}"
if [ -f "docker-compose.yml" ]; then
    echo "管理后端容器挂载:"
    grep -A 5 "volumes:" docker-compose.yml | grep -E "\./data|DATA_ROOT" | sed 's/^/  /'
else
    echo -e "${RED}❌ docker-compose.yml不存在${NC}"
fi
echo ""

# 检查管理后端容器状态
echo -e "${YELLOW}🔧 检查管理后端容器状态:${NC}"
if docker ps | grep -q "ai4s-platform-backend"; then
    echo "  管理后端容器正在运行"
    
    echo "  检查容器内挂载点:"
    docker exec ai4s-platform-backend ls -la /app/data/ 2>/dev/null | sed 's/^/    /' || echo "    无法访问 /app/data"
    
    echo "  检查子目录:"
    for subdir in users shared-ro shared-rw groups; do
        if docker exec ai4s-platform-backend test -d "/app/data/$subdir" 2>/dev/null; then
            echo -e "    ${GREEN}✓ /app/data/$subdir${NC}"
        else
            echo -e "    ${RED}❌ /app/data/$subdir${NC}"
        fi
    done
else
    echo "  管理后端容器未运行"
fi
echo ""

# 修复建议
echo -e "${YELLOW}📋 修复建议:${NC}"
echo "1. 运行简化设置脚本:"
echo "   ./scripts/setup-simple.sh"
echo ""
echo "2. 重启管理后端服务:"
echo "   docker compose restart ai4s-platform"
echo ""
echo "3. 检查用户容器创建时的挂载日志"

echo -e "${GREEN}✅ 测试完成！${NC}" 