#!/bin/bash

# 获取环境变量
DEV_USER=${DEV_USER:-developer}
DEV_UID=${DEV_UID:-1001}
DEV_GID=${DEV_GID:-1001}
DEV_PASSWORD=${DEV_PASSWORD:-developer123}

echo "=== 容器启动脚本 ==="
echo "用户: $DEV_USER"
echo "UID: $DEV_UID"
echo "GID: $DEV_GID"

echo ""
echo "=== 目录挂载检查 ==="
echo "个人主目录: /home/$DEV_USER $([ -d "/home/$DEV_USER" ] && echo "✓" || echo "✗")"
echo "共享目录: /shared $([ -d "/shared" ] && echo "✓" || echo "✗")"
echo "工作空间: /workspace $([ -d "/workspace" ] && echo "✓" || echo "✗")"
echo ""

# 检查是否以root身份运行
if [ "$(id -u)" != "0" ]; then
    echo "错误: 容器需要以root身份启动才能创建用户"
    exit 1
fi

# 创建用户组
if ! getent group $DEV_USER > /dev/null 2>&1; then
    if groupadd -g $DEV_GID $DEV_USER 2>/dev/null; then
        echo "创建用户组: $DEV_USER ($DEV_GID)"
    else
        echo "警告: 用户组创建失败，可能已存在"
    fi
fi

# 创建用户
if ! id -u $DEV_USER > /dev/null 2>&1; then
    # 先创建用户主目录
    mkdir -p /home/$DEV_USER
    
    if useradd -m -u $DEV_UID -g $DEV_GID -s /bin/bash -d /home/$DEV_USER $DEV_USER 2>/dev/null; then
        echo "创建用户: $DEV_USER ($DEV_UID:$DEV_GID)"
        
        # 设置密码
        if echo "$DEV_USER:$DEV_PASSWORD" | chpasswd; then
            echo "密码设置成功"
        else
            echo "警告: 密码设置失败"
        fi
        
        # 添加到sudo组
        if usermod -aG sudo $DEV_USER 2>/dev/null; then
            echo "添加到sudo组成功"
        fi
        
        # 设置sudo免密
        if echo "$DEV_USER ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers; then
            echo "sudo免密设置成功"
        fi
    else
        echo "警告: 用户创建失败，可能已存在"
    fi
else
    echo "用户 $DEV_USER 已存在"
fi

# 确保用户主目录权限正确
if chown -R $DEV_UID:$DEV_GID /home/$DEV_USER 2>/dev/null; then
    echo "用户主目录权限设置成功"
else
    echo "警告: 用户主目录权限设置失败"
fi

# 创建必要的目录
mkdir -p /home/$DEV_USER/.jupyter
mkdir -p /home/$DEV_USER/.vscode-server
mkdir -p /home/$DEV_USER/.config/code-server

# 设置目录权限
chown -R $DEV_UID:$DEV_GID /home/$DEV_USER/.jupyter 2>/dev/null
chown -R $DEV_UID:$DEV_GID /home/$DEV_USER/.vscode-server 2>/dev/null
chown -R $DEV_UID:$DEV_GID /home/$DEV_USER/.config 2>/dev/null

# 确保挂载目录存在并设置权限
if [ -d "/workspace" ]; then
    chown -R $DEV_UID:$DEV_GID /workspace 2>/dev/null || echo "警告: workspace权限设置失败，但目录可用"
    chmod 755 /workspace 2>/dev/null
    echo "workspace目录权限设置完成"
else
    echo "警告: workspace目录不存在"
fi

if [ -d "/shared" ]; then
    chmod 755 /shared 2>/dev/null
    echo "shared目录权限设置完成"
else
    echo "警告: shared目录不存在"
fi

# 生成Jupyter配置
if id -u $DEV_USER > /dev/null 2>&1; then
    su - $DEV_USER -c "python3 -m jupyter lab --generate-config" 2>/dev/null || echo "警告: Jupyter配置生成失败"
fi

# 配置Jupyter Lab
if mkdir -p /home/$DEV_USER/.jupyter; then
    # 生成密码哈希
    JUPYTER_PASSWORD_HASH=$(python3 -c "from jupyter_server.auth import passwd; print(passwd('$DEV_PASSWORD'))")
    
    cat > /home/$DEV_USER/.jupyter/jupyter_lab_config.py << EOF
c.ServerApp.ip = '0.0.0.0'
c.ServerApp.port = 8888
c.ServerApp.allow_root = True
c.ServerApp.open_browser = False
c.ServerApp.token = ''
c.ServerApp.password = '$JUPYTER_PASSWORD_HASH'
c.ServerApp.allow_origin = '*'
c.ServerApp.allow_remote_access = True
c.ServerApp.root_dir = '/home/$DEV_USER'
c.ServerApp.disable_check_xsrf = True
EOF

    chown $DEV_UID:$DEV_GID /home/$DEV_USER/.jupyter/jupyter_lab_config.py 2>/dev/null
fi

# 配置code-server
if mkdir -p /home/$DEV_USER/.config/code-server; then
    cat > /home/$DEV_USER/.config/code-server/config.yaml << EOF
bind-addr: 0.0.0.0:8080
auth: password
password: $DEV_PASSWORD
cert: false
EOF

    chown -R $DEV_UID:$DEV_GID /home/$DEV_USER/.config/code-server 2>/dev/null
fi

# 启动SSH服务
echo "启动SSH服务..."
if service ssh start; then
    echo "SSH服务启动成功"
else
    echo "警告: SSH服务启动失败，尝试手动启动..."
    /usr/sbin/sshd -D &
fi

# 创建启动脚本
cat > /home/$DEV_USER/start_services.sh << EOF
#!/bin/bash

echo "=== 启动开发环境服务 ==="

# 启动Jupyter Lab
echo "启动Jupyter Lab..."
nohup jupyter lab --config=/home/\$DEV_USER/.jupyter/jupyter_lab_config.py > /tmp/jupyter.log 2>&1 &
echo "Jupyter Lab PID: \$!"

# 启动code-server (VSCode Server)
echo "启动VSCode Server..."
nohup code-server > /tmp/code-server.log 2>&1 &
echo "VSCode Server PID: \$!"

# 启动TensorBoard (可选)
if [ -d "/home/\$DEV_USER/logs" ]; then
    echo "启动TensorBoard..."
    nohup tensorboard --logdir=/home/\$DEV_USER/logs --host=0.0.0.0 --port=6006 > /tmp/tensorboard.log 2>&1 &
    echo "TensorBoard PID: \$!"
fi

echo "=== 服务启动完成 ==="
echo "SSH: 端口 22 (用户名: $DEV_USER, 密码: $DEV_PASSWORD)"
echo "VSCode Server: 端口 8080 (密码: $DEV_PASSWORD)"
echo "Jupyter Lab: 端口 8888 (密码: $DEV_PASSWORD)"
echo "TensorBoard: 端口 6006 (无需认证)"
echo ""
echo "日志文件位置:"
echo "  Jupyter Lab: /tmp/jupyter.log"
echo "  VSCode Server: /tmp/code-server.log"
echo "  TensorBoard: /tmp/tensorboard.log"
EOF

# 设置启动脚本权限
if [ -f /home/$DEV_USER/start_services.sh ]; then
    chmod +x /home/$DEV_USER/start_services.sh
    chown $DEV_UID:$DEV_GID /home/$DEV_USER/start_services.sh 2>/dev/null
fi

# 创建欢迎信息
if mkdir -p /home/$DEV_USER; then
    cat > /home/$DEV_USER/README.md << EOF
# 开发环境使用指南

## 服务访问

- **SSH**: 使用用户名 \`$DEV_USER\` 和密码 \`$DEV_PASSWORD\` 登录
- **VSCode Server**: 浏览器访问 http://host:port，密码: \`$DEV_PASSWORD\`
- **Jupyter Lab**: 浏览器访问 http://host:port，密码: \`$DEV_PASSWORD\`
- **TensorBoard**: 浏览器访问 http://host:port (无需认证)

## 目录结构

- \`/home/$DEV_USER\`: 个人主目录 (读写，私有)
- \`/shared\`: 共享只读目录 (所有用户共享，只读)
- \`/workspace\`: 共享工作区 (所有用户共享，可读写)

## 启动服务

运行以下命令启动所有服务:
\`\`\`bash
./start_services.sh
\`\`\`

## 预装软件

- Python 3 + 常用AI/ML库 (TensorFlow, PyTorch, Jupyter等)
- Git, Vim, htop等开发工具
- Node.js和npm

## GPU支持

容器已配置NVIDIA CUDA支持，可直接使用GPU进行深度学习训练。

EOF

    chown $DEV_UID:$DEV_GID /home/$DEV_USER/README.md 2>/dev/null
fi

# 切换到用户身份启动服务
echo "切换到用户 $DEV_USER 启动服务..."
if id -u $DEV_USER > /dev/null 2>&1 && [ -f /home/$DEV_USER/start_services.sh ]; then
    su - $DEV_USER -c "/home/$DEV_USER/start_services.sh" 2>/dev/null || echo "警告: 服务启动失败"
else
    echo "警告: 用户不存在或启动脚本缺失，直接启动服务..."
    # 直接启动基础服务
    nohup jupyter lab --ip=0.0.0.0 --port=8888 --allow-root --no-browser --PasswordIdentityProvider.hashed_password="$(python3 -c "from jupyter_server.auth import passwd; print(passwd('$DEV_PASSWORD'))")" > /tmp/jupyter.log 2>&1 &
    nohup code-server --bind-addr=0.0.0.0:8080 --auth=password --password="$DEV_PASSWORD" > /tmp/code-server.log 2>&1 &
fi

# 保持容器运行
echo "=== 容器启动完成 ==="
echo "SSH登录: ssh -p PORT $DEV_USER@HOST"
echo "密码: $DEV_PASSWORD"
tail -f /dev/null