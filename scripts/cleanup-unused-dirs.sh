#!/bin/bash

# 清理容器内无用目录的脚本

echo "🧹 清理容器内无用目录..."

# 检查管理后端容器是否运行
if ! docker ps | grep -q "ai4s-platform-backend"; then
    echo "❌ 管理后端容器未运行"
    exit 1
fi

echo "📁 检查容器内无用目录..."

# 检查 /app/shared 目录
if docker exec ai4s-platform-backend test -d /app/shared; then
    echo "  发现无用目录: /app/shared"
    if docker exec ai4s-platform-backend test -z "$(ls -A /app/shared)"; then
        echo "  ✓ 目录为空，可以安全删除"
        docker exec ai4s-platform-backend rmdir /app/shared
        echo "  ✓ 已删除 /app/shared"
    else
        echo "  ⚠️  目录不为空，请手动检查"
    fi
else
    echo "  ✓ /app/shared 目录不存在"
fi

# 检查 /app/workspace 目录
if docker exec ai4s-platform-backend test -d /app/workspace; then
    echo "  发现无用目录: /app/workspace"
    if docker exec ai4s-platform-backend test -z "$(ls -A /app/workspace)"; then
        echo "  ✓ 目录为空，可以安全删除"
        docker exec ai4s-platform-backend rmdir /app/workspace
        echo "  ✓ 已删除 /app/workspace"
    else
        echo "  ⚠️  目录不为空，请手动检查"
    fi
else
    echo "  ✓ /app/workspace 目录不存在"
fi

echo "✅ 清理完成！" 