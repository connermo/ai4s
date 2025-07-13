#!/bin/bash

# 测试shared目录挂载的脚本

echo "=== Shared目录挂载测试 ==="
echo ""

echo "🔍 检查宿主机shared目录:"
echo "路径: $(pwd)/shared"
echo "内容:"
ls -la shared/ | sed 's/^/  /'
echo "文件数量: $(ls shared/ 2>/dev/null | wc -l)"
echo ""

echo "🐳 检查Docker Compose配置:"
echo "docker-compose.yml挂载:"
grep -A5 "volumes:" docker-compose.yml | grep shared | sed 's/^/  /'
echo ""

echo "📄 检查.env配置:"
echo "SHARED_DATA_PATH=$(grep SHARED_DATA_PATH .env | head -1)"
echo ""

echo "🔧 重启服务测试..."
echo "停止服务..."
docker compose down

echo "启动服务..."
docker compose up -d

sleep 5

echo ""
echo "📊 检查管理后端容器内的shared目录:"
docker exec gpu-platform-backend ls -la /app/shared/ 2>/dev/null | sed 's/^/  /' || echo "  无法访问容器或目录不存在"

echo ""
echo "✅ 测试完成！"
echo ""
echo "如果管理后端容器内的/app/shared目录有内容，"
echo "那么新创建的用户容器中的/shared目录也应该有相同的内容。"