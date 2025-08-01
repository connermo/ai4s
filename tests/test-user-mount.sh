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
echo "DATA_ROOT: ${DATA_ROOT:-未设置}"
echo ""

# 检查宿主机目录
echo "📁 检查宿主机目录结构:"
if [ -n "$DATA_ROOT" ]; then
    echo "数据根目录: $DATA_ROOT"
    ls -la "$DATA_ROOT/" | sed 's/^/  /'
    echo ""
    
    echo "用户目录: $DATA_ROOT/users"
    ls -la "$DATA_ROOT/users/" | sed 's/^/  /'
    echo ""
    
    echo "共享只读目录: $DATA_ROOT/shared-ro"
    ls -la "$DATA_ROOT/shared-ro/" | sed 's/^/  /'
    echo ""
    
    echo "共享读写目录: $DATA_ROOT/shared-rw"
    ls -la "$DATA_ROOT/shared-rw/" | sed 's/^/  /'
    echo ""
    
    echo "组目录: $DATA_ROOT/groups"
    ls -la "$DATA_ROOT/groups/" | sed 's/^/  /'
    echo ""
else
    echo "❌ DATA_ROOT 环境变量未设置"
    echo "请运行: ./scripts/setup-simple.sh"
    exit 1
fi

# 检查Docker Compose配置
echo "🐳 检查Docker Compose挂载配置:"
echo "管理后端容器挂载:"
grep -A5 "volumes:" docker-compose.yml | grep -E "(DATA_ROOT|/app/data)" | sed 's/^/  /'
echo ""

# 检查管理后端容器状态
echo "🔧 检查管理后端容器状态:"
if docker ps | grep -q "ai4s-platform-backend"; then
    echo "  管理后端容器正在运行"
    
    echo "  检查容器内环境变量:"
    docker exec ai4s-platform-backend env | grep DATA_ROOT | sed 's/^/    /'
    echo ""
    
    echo "  检查容器内数据目录结构:"
    docker exec ai4s-platform-backend ls -la /app/data/ | sed 's/^/    /'
    echo ""
    
    echo "  检查容器内子目录:"
    docker exec ai4s-platform-backend ls -la /app/data/users/ | sed 's/^/    /' || echo "    无法访问 /app/data/users"
    docker exec ai4s-platform-backend ls -la /app/data/shared-ro/ | sed 's/^/    /' || echo "    无法访问 /app/data/shared-ro"
    docker exec ai4s-platform-backend ls -la /app/data/shared-rw/ | sed 's/^/    /' || echo "    无法访问 /app/data/shared-rw"
    docker exec ai4s-platform-backend ls -la /app/data/groups/ | sed 's/^/    /' || echo "    无法访问 /app/data/groups"
else
    echo "  管理后端容器未运行"
fi

echo ""
echo "📋 修复建议:"
echo "1. 如果DATA_ROOT未设置，运行:"
echo "   ./scripts/setup-simple.sh"
echo ""
echo "2. 如果目录结构不正确，运行:"
echo "   mkdir -p $DATA_ROOT/{users,shared-ro,shared-rw,groups}"
echo "   chmod 755 $DATA_ROOT/{users,shared-ro,shared-rw,groups}"
echo ""
echo "3. 重启管理后端服务:"
echo "   docker compose restart ai4s-platform"
echo ""
echo "4. 检查用户容器创建时的挂载日志"
echo ""

echo "✅ 测试完成！" 