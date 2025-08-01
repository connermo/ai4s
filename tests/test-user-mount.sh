#!/bin/bash

# 测试用户目录挂载的脚本

echo "=== 用户目录挂载测试 ==="
echo ""

# 加载.env文件
if [ -f ".env" ]; then
    export $(grep -v '^#' .env | xargs)
fi

# 检查环境变量配置
echo "🔍 检查环境变量配置:"
echo "HOST_USERS_PATH: ${HOST_USERS_PATH:-未设置}"
echo "HOST_SHARED_RO_PATH: ${HOST_SHARED_RO_PATH:-未设置}"
echo "HOST_SHARED_RW_PATH: ${HOST_SHARED_RW_PATH:-未设置}"
echo "HOST_GROUPS_PATH: ${HOST_GROUPS_PATH:-未设置}"
echo ""

# 检查宿主机目录
echo "📁 检查宿主机目录结构:"
echo "用户目录: $(pwd)/data/users"
ls -la data/users/ | sed 's/^/  /'
echo ""

echo "共享只读目录: $(pwd)/data/shared-ro"
ls -la data/shared-ro/ | sed 's/^/  /'
echo ""

echo "共享读写目录: $(pwd)/data/shared-rw"
ls -la data/shared-rw/ | sed 's/^/  /'
echo ""

echo "组目录: $(pwd)/data/groups"
ls -la data/groups/ | sed 's/^/  /'
echo ""

# 检查Docker Compose配置
echo "🐳 检查Docker Compose挂载配置:"
echo "管理后端容器挂载:"
grep -A10 "volumes:" docker-compose.yml | grep -E "(users|shared|groups)" | sed 's/^/  /'
echo ""

# 检查管理后端容器状态
echo "🔧 检查管理后端容器状态:"
if docker ps | grep -q "ai4s-platform-backend"; then
    echo "  管理后端容器正在运行"
    
    echo "  检查容器内挂载点:"
    docker exec ai4s-platform-backend ls -la /app/users/ 2>/dev/null | sed 's/^/    /' || echo "    无法访问 /app/users"
    docker exec ai4s-platform-backend ls -la /shared-ro/ 2>/dev/null | sed 's/^/    /' || echo "    无法访问 /shared-ro"
    docker exec ai4s-platform-backend ls -la /shared-rw/ 2>/dev/null | sed 's/^/    /' || echo "    无法访问 /shared-rw"
    docker exec ai4s-platform-backend ls -la /app/groups/ 2>/dev/null | sed 's/^/    /' || echo "    无法访问 /app/groups"
else
    echo "  管理后端容器未运行"
fi

echo ""
echo "📋 修复建议:"
echo "1. 确保环境变量正确设置:"
echo "   export HOST_USERS_PATH=\$(pwd)/data/users"
echo "   export HOST_SHARED_RO_PATH=\$(pwd)/data/shared-ro"
echo "   export HOST_SHARED_RW_PATH=\$(pwd)/data/shared-rw"
echo "   export HOST_GROUPS_PATH=\$(pwd)/data/groups"
echo ""
echo "2. 确保目录权限正确:"
echo "   chmod 755 data/users data/shared-ro data/shared-rw data/groups"
echo ""
echo "3. 重启管理后端服务:"
echo "   docker compose restart ai4s-platform"
echo ""
echo "4. 检查用户容器创建时的挂载日志"
echo ""

echo "✅ 测试完成！" 