#!/bin/bash

# 设置组管理员对shared-ro目录的写权限
# 用法: ./scripts/set-admin-permissions.sh <用户名> <组名>

if [ $# -lt 2 ]; then
    echo "用法: $0 <用户名> <组名>"
    echo "示例: $0 alice research-team"
    exit 1
fi

USERNAME="$1"
GROUP_NAME="$2"
CONTAINER_NAME="dev-$USERNAME"

echo "=== 设置组管理员权限 ==="
echo "用户: $USERNAME"
echo "组: $GROUP_NAME"
echo "容器: $CONTAINER_NAME"
echo ""

# 检查容器是否存在且运行中
if ! docker ps --format "{{.Names}}" | grep -q "^$CONTAINER_NAME$"; then
    echo "错误: 容器 $CONTAINER_NAME 不存在或未运行"
    exit 1
fi

# 在容器内设置管理员权限
echo "设置管理员对 shared-ro 目录的写权限..."
docker exec "$CONTAINER_NAME" bash -c "
    SHARED_RO_DIR=\"/groups/$GROUP_NAME/shared-ro\"
    
    if [ ! -d \"\$SHARED_RO_DIR\" ]; then
        echo \"错误: 目录 \$SHARED_RO_DIR 不存在\"
        exit 1
    fi
    
    echo \"目录: \$SHARED_RO_DIR\"
    echo \"原权限: \$(ls -ld \"\$SHARED_RO_DIR\" | cut -d' ' -f1)\"
    
    # 尝试使用ACL设置权限
    if command -v setfacl >/dev/null 2>&1; then
        echo \"使用ACL设置权限...\"
        setfacl -m \"u:$USERNAME:rwx\" \"\$SHARED_RO_DIR\" 2>/dev/null || {
            echo \"ACL设置失败，使用传统方法...\"
            chown \"$USERNAME:\$GROUP_NAME\" \"\$SHARED_RO_DIR\" 2>/dev/null || true
            chmod 755 \"\$SHARED_RO_DIR\" 2>/dev/null || true
        }
        # 设置默认ACL，新文件也会有正确权限
        setfacl -d -m \"u:$USERNAME:rwx\" \"\$SHARED_RO_DIR\" 2>/dev/null || true
        setfacl -d -m \"g:$GROUP_NAME:r-x\" \"\$SHARED_RO_DIR\" 2>/dev/null || true
        
        echo \"ACL权限设置完成\"
        getfacl \"\$SHARED_RO_DIR\" 2>/dev/null || echo \"无法显示ACL权限\"
    else
        echo \"使用传统权限管理...\"
        chown \"$USERNAME:$GROUP_NAME\" \"\$SHARED_RO_DIR\" 2>/dev/null || true
        chmod 755 \"\$SHARED_RO_DIR\" 2>/dev/null || true
        echo \"传统权限设置完成\"
    fi
    
    echo \"新权限: \$(ls -ld \"\$SHARED_RO_DIR\" | cut -d' ' -f1)\"
    
    # 创建管理员标记文件
    GROUP_DIR=\"/groups/$GROUP_NAME\"
    if [ -d \"\$GROUP_DIR\" ]; then
        if ! grep -q \"^$USERNAME\$\" \"\$GROUP_DIR/.group_admins\" 2>/dev/null; then
            echo \"$USERNAME\" >> \"\$GROUP_DIR/.group_admins\"
            echo \"添加管理员标记: $USERNAME\"
        fi
        chmod 644 \"\$GROUP_DIR/.group_admins\" 2>/dev/null || true
    fi
    
    echo \"✓ 用户 $USERNAME 现在对组 $GROUP_NAME 的 shared-ro 目录有写权限\"
" || {
    echo "权限设置失败"
    exit 1
}

echo ""
echo "权限设置完成！"
echo ""
echo "验证权限:"
echo "docker exec $CONTAINER_NAME ls -la /groups/$GROUP_NAME/"