#!/bin/bash

echo "=== 组目录权限修复工具 ==="
echo ""

# 设置默认路径
HOST_GROUPS_PATH="${HOST_GROUPS_PATH:-./data/groups}"

echo "1. 修复宿主机组目录权限..."
if [ -d "$HOST_GROUPS_PATH" ]; then
    echo "  处理目录: $HOST_GROUPS_PATH"
    
    # 确保根目录权限正确
    chmod 755 "$HOST_GROUPS_PATH"
    echo "  ✓ 设置根目录权限: 755"
    
    # 修复每个组目录的权限
    for group_dir in "$HOST_GROUPS_PATH"/*; do
        if [ -d "$group_dir" ]; then
            group_name=$(basename "$group_dir")
            echo "  修复组目录: $group_name"
            
            # 设置目录权限为775，确保组成员有写权限
            chmod -R 775 "$group_dir"
            echo "    ✓ 设置权限: 775"
            
            # 显示最终权限
            echo "    权限结果: $(ls -ld "$group_dir" | cut -d' ' -f1)"
        fi
    done
else
    echo "  创建组目录: $HOST_GROUPS_PATH"
    mkdir -p "$HOST_GROUPS_PATH"
    chmod 755 "$HOST_GROUPS_PATH"
fi

echo ""
echo "2. 修复容器内组目录权限..."

# 获取正在运行的用户容器
containers=$(docker ps --filter "name=dev-" --format "{{.Names}}")

if [ -z "$containers" ]; then
    echo "  没有找到正在运行的用户容器"
else
    for container in $containers; do
        echo ""
        echo "  修复容器: $container"
        
        # 在容器内执行权限修复脚本
        docker exec "$container" bash -c "
            echo '    检查 /groups 目录...'
            if [ ! -d '/groups' ]; then
                echo '    创建 /groups 目录'
                mkdir -p /groups
                chmod 755 /groups
            fi
            
            echo '    修复组目录权限...'
            for group_dir in /groups/*; do
                if [ -d \"\$group_dir\" ]; then
                    group_name=\$(basename \"\$group_dir\")
                    echo \"      处理组: \$group_name\"
                    
                    # 检查组是否存在
                    if getent group \"\$group_name\" > /dev/null 2>&1; then
                        # 设置正确的所有者和权限
                        chown -R \"root:\$group_name\" \"\$group_dir\" 2>/dev/null || true
                        chmod -R 775 \"\$group_dir\" 2>/dev/null || true
                        find \"\$group_dir\" -type d -exec chmod g+s {} \; 2>/dev/null || true
                        perm=\$(ls -ld \"\$group_dir\" | cut -d' ' -f1)
                        echo \"        ✓ 权限: \$perm\"
                    else
                        echo \"        ⚠ 系统组 \$group_name 不存在\"
                    fi
                fi
            done
            
            echo '    容器权限修复完成'
        " 2>/dev/null || echo "    容器 $container 权限修复失败"
    done
fi

echo ""
echo "3. 权限修复完成!"
echo ""
echo "建议执行以下命令验证权限:"
echo "  ./scripts/check-group-permissions.sh"
echo ""
echo "在容器内测试写权限:"
echo "  docker exec <容器名> /scripts/test-group-write-permissions.sh"