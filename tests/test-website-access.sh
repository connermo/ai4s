#!/bin/bash

echo "=== 网站访问测试 ==="

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 加载.env文件
if [ -f ".env" ]; then
    export $(grep -v '^#' .env | xargs)
fi

# 检查服务状态
echo -e "${BLUE}检查服务状态...${NC}"
if docker ps | grep -q "ai4s-platform-backend"; then
    echo -e "${GREEN}✓ 管理后端容器正在运行${NC}"
else
    echo -e "${RED}✗ 管理后端容器未运行${NC}"
    echo "请运行: docker compose up -d"
    exit 1
fi

if docker ps | grep -q "gpu-platform-mysql"; then
    echo -e "${GREEN}✓ MySQL容器正在运行${NC}"
else
    echo -e "${RED}✗ MySQL容器未运行${NC}"
    echo "请运行: docker compose up -d"
    exit 1
fi

echo ""

# 检查端口监听
echo -e "${BLUE}检查端口监听...${NC}"
if netstat -tlnp | grep -q ":8080"; then
    echo -e "${GREEN}✓ 端口8080正在监听${NC}"
else
    echo -e "${RED}✗ 端口8080未监听${NC}"
fi

echo ""

# 测试网站访问
echo -e "${BLUE}测试网站访问...${NC}"

# 测试主页
echo "测试主页 (http://localhost:8080/):"
if curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/ | grep -q "200\|302"; then
    echo -e "${GREEN}✓ 主页可访问${NC}"
else
    echo -e "${RED}✗ 主页无法访问${NC}"
fi

# 测试登录页面
echo "测试登录页面 (http://localhost:8080/admin-login):"
if curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/admin-login | grep -q "200"; then
    echo -e "${GREEN}✓ 登录页面可访问${NC}"
else
    echo -e "${RED}✗ 登录页面无法访问${NC}"
fi

# 测试API接口
echo "测试API接口 (http://localhost:8080/api/users):"
API_RESPONSE=$(curl -s -w "%{http_code}" http://localhost:8080/api/users)
if echo "$API_RESPONSE" | grep -q "缺少Authorization头"; then
    echo -e "${GREEN}✓ API接口正常（需要认证）${NC}"
elif echo "$API_RESPONSE" | grep -q "200"; then
    echo -e "${GREEN}✓ API接口正常${NC}"
else
    echo -e "${RED}✗ API接口无法访问${NC}"
fi

# 测试静态资源
echo "测试静态资源 (http://localhost:8080/static/css/bootstrap.min.css):"
if curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/static/css/bootstrap.min.css | grep -q "200"; then
    echo -e "${GREEN}✓ 静态资源可访问${NC}"
else
    echo -e "${RED}✗ 静态资源无法访问${NC}"
fi

echo ""

# 检查容器日志
echo -e "${BLUE}检查容器日志...${NC}"
echo "管理后端容器最近日志:"
docker logs ai4s-platform-backend --tail 5 2>/dev/null | sed 's/^/  /'

echo ""

# 显示访问信息
echo -e "${GREEN}=== 网站访问信息 ===${NC}"
echo -e "${BLUE}访问地址:${NC}"
echo "  管理界面: http://localhost:8080"
echo "  登录页面: http://localhost:8080/admin-login"
echo "  API接口: http://localhost:8080/api"
echo ""
echo -e "${BLUE}默认管理员账号:${NC}"
echo "  用户名: admin"
echo "  密码: admin123"
echo ""
echo -e "${BLUE}常用命令:${NC}"
echo "  查看日志: docker logs ai4s-platform-backend -f"
echo "  重启服务: docker compose restart ai4s-platform"
echo "  停止服务: docker compose down" 