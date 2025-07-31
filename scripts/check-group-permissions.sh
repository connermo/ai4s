#!/bin/bash

echo "=== 组目录权限检查工具 ==="
echo ""

# 检查宿主机组目录权限
HOST_GROUPS_PATH="${HOST_GROUPS_PATH:-./data/groups}"
echo "1. 宿主机组目录权限 ($HOST_GROUPS_PATH):"
if [ -d "$HOST_GROUPS_PATH" ]; then
    ls -la "$HOST_GROUPS_PATH"
    echo ""
    for dir in "$HOST_GROUPS_PATH"/*; do
        if [ -d "$dir" ]; then
            echo "  $(basename "$dir"): $(ls -ld "$dir")"
        fi
    done
else
    echo "  宿主机组目录不存在: $HOST_GROUPS_PATH"
fi

echo ""
echo "2. 检查容器内组目录权限:"

# 获取正在运行的用户容器
containers=$(docker ps --filter "name=dev-" --format "{{.Names}}")

if [ -z "$containers" ]; then
    echo "  没有找到正在运行的用户容器"
else
    for container in $containers; do
        echo ""
        echo "  容器: $container"
        echo "  /groups 目录:"
        docker exec "$container" ls -la /groups 2>/dev/null || echo "    无法访问 /groups 目录"
        
        echo "  用户组信息:"
        docker exec "$container" sh -c 'echo "    用户: $(whoami), UID: $(id -u), GID: $(id -g)"' 2>/dev/null
        docker exec "$container" sh -c 'echo "    所属组: $(groups)"' 2>/dev/null
        
        echo "  组目录详细权限:"
        docker exec "$container" find /groups -maxdepth 2 -type d -exec ls -ld {} \; 2>/dev/null | head -10
    done
fi

echo ""
echo "3. 权限问题诊断建议:"
echo "  - 确保宿主机目录权限为 775"
echo "  - 确保容器内目录所有者为 root:组名"
echo "  - 确保用户已加入对应的组"
echo "  - 确保目录设置了组粘滞位 (g+s)"