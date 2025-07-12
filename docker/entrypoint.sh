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

# 创建用户组
if ! getent group $DEV_USER > /dev/null 2>&1; then
    groupadd -g $DEV_GID $DEV_USER
    echo "创建用户组: $DEV_USER ($DEV_GID)"
fi

# 创建用户
if ! id -u $DEV_USER > /dev/null 2>&1; then
    useradd -m -u $DEV_UID -g $DEV_GID -s /bin/bash $DEV_USER
    echo "创建用户: $DEV_USER ($DEV_UID:$DEV_GID)"
    
    # 设置密码
    echo "$DEV_USER:$DEV_PASSWORD" | chpasswd
    
    # 添加到sudo组
    usermod -aG sudo $DEV_USER
    
    # 设置sudo免密
    echo "$DEV_USER ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
fi

# 确保用户主目录权限正确
chown -R $DEV_UID:$DEV_GID /home/$DEV_USER

# 创建必要的目录
mkdir -p /home/$DEV_USER/.jupyter
mkdir -p /home/$DEV_USER/.vscode-server
mkdir -p /home/$DEV_USER/.config/code-server

# 设置目录权限
chown -R $DEV_UID:$DEV_GID /home/$DEV_USER/.jupyter
chown -R $DEV_UID:$DEV_GID /home/$DEV_USER/.vscode-server
chown -R $DEV_UID:$DEV_GID /home/$DEV_USER/.config

# 设置共享目录权限
chown -R $DEV_UID:$DEV_GID /workspace
chmod 755 /shared

# 生成Jupyter配置
su - $DEV_USER -c "python3 -m jupyter lab --generate-config"

# 配置Jupyter Lab
cat > /home/$DEV_USER/.jupyter/jupyter_lab_config.py << EOF
c.ServerApp.ip = '0.0.0.0'
c.ServerApp.port = 8888
c.ServerApp.allow_root = True
c.ServerApp.open_browser = False
c.ServerApp.token = ''
c.ServerApp.password = ''
c.ServerApp.allow_origin = '*'
c.ServerApp.allow_remote_access = True
c.ServerApp.root_dir = '/home/$DEV_USER'
EOF

# 配置code-server
cat > /home/$DEV_USER/.config/code-server/config.yaml << EOF
bind-addr: 0.0.0.0:8080
auth: none
cert: false
EOF

# 设置配置文件权限
chown $DEV_UID:$DEV_GID /home/$DEV_USER/.jupyter/jupyter_lab_config.py
chown -R $DEV_UID:$DEV_GID /home/$DEV_USER/.config/code-server

# 启动SSH服务
service ssh start
echo "SSH服务已启动"

# 创建启动脚本
cat > /home/$DEV_USER/start_services.sh << 'EOF'
#!/bin/bash

echo "=== 启动开发环境服务 ==="

# 启动Jupyter Lab
echo "启动Jupyter Lab..."
nohup jupyter lab --config=/home/$DEV_USER/.jupyter/jupyter_lab_config.py > /tmp/jupyter.log 2>&1 &
echo "Jupyter Lab PID: $!"

# 启动code-server (VSCode Server)
echo "启动VSCode Server..."
nohup code-server > /tmp/code-server.log 2>&1 &
echo "VSCode Server PID: $!"

# 启动TensorBoard (可选)
if [ -d "/home/$DEV_USER/logs" ]; then
    echo "启动TensorBoard..."
    nohup tensorboard --logdir=/home/$DEV_USER/logs --host=0.0.0.0 --port=6006 > /tmp/tensorboard.log 2>&1 &
    echo "TensorBoard PID: $!"
fi

echo "=== 服务启动完成 ==="
echo "SSH: 端口 22"
echo "VSCode Server: 端口 8080"
echo "Jupyter Lab: 端口 8888"
echo "TensorBoard: 端口 6006"
echo ""
echo "日志文件位置:"
echo "  Jupyter Lab: /tmp/jupyter.log"
echo "  VSCode Server: /tmp/code-server.log"
echo "  TensorBoard: /tmp/tensorboard.log"
EOF

# 设置启动脚本权限
chmod +x /home/$DEV_USER/start_services.sh
chown $DEV_UID:$DEV_GID /home/$DEV_USER/start_services.sh

# 创建欢迎信息
cat > /home/$DEV_USER/README.md << EOF
# 开发环境使用指南

## 服务访问

- **SSH**: 使用用户名 \`$DEV_USER\` 和密码 \`$DEV_PASSWORD\` 登录
- **VSCode Server**: 浏览器访问 http://host:port
- **Jupyter Lab**: 浏览器访问 http://host:port  
- **TensorBoard**: 浏览器访问 http://host:port

## 目录结构

- \`/home/$DEV_USER\`: 个人主目录
- \`/shared\`: 只读共享目录
- \`/workspace\`: 读写共享目录

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

chown $DEV_UID:$DEV_GID /home/$DEV_USER/README.md

# 切换到用户身份启动服务
echo "切换到用户 $DEV_USER 启动服务..."
su - $DEV_USER -c "/home/$DEV_USER/start_services.sh"

# 保持容器运行
echo "=== 容器启动完成 ==="
tail -f /dev/null