#!/bin/bash

# 容器服务密码修改脚本
# 用户可以在容器内运行此脚本来修改SSH、VSCode、Jupyter的密码

echo "========================================"
echo "    GPU开发环境 - 密码修改工具"
echo "========================================"
echo ""

# 获取当前用户
CURRENT_USER=$(whoami)
if [ "$CURRENT_USER" = "root" ]; then
    echo "⚠️  请不要以root用户运行此脚本"
    echo "请切换到您的用户账户后再运行"
    exit 1
fi

echo "当前用户: $CURRENT_USER"
echo ""

# 提示用户输入新密码
echo "📝 请输入新密码:"
echo "   - 密码长度至少6位"
echo "   - 建议包含大小写字母、数字和特殊字符"
echo ""

read -s -p "新密码: " NEW_PASSWORD
echo ""
read -s -p "确认密码: " CONFIRM_PASSWORD
echo ""

# 验证密码
if [ -z "$NEW_PASSWORD" ]; then
    echo "❌ 密码不能为空"
    exit 1
fi

if [ ${#NEW_PASSWORD} -lt 6 ]; then
    echo "❌ 密码长度至少6位"
    exit 1
fi

if [ "$NEW_PASSWORD" != "$CONFIRM_PASSWORD" ]; then
    echo "❌ 两次输入的密码不一致"
    exit 1
fi

echo ""
echo "🔄 正在修改密码..."
echo ""

# 1. 修改系统用户密码（用于SSH登录）
echo "1️⃣  修改SSH登录密码..."
if echo "$CURRENT_USER:$NEW_PASSWORD" | sudo chpasswd; then
    echo "✅ SSH密码修改成功"
else
    echo "❌ SSH密码修改失败"
    exit 1
fi

# 2. 更新Jupyter配置
echo "2️⃣  更新Jupyter Lab配置..."
mkdir -p ~/.jupyter

# 使用现代化的Jupyter密码设置方法
# 生成配置文件使用推荐的PasswordIdentityProvider
python3 -c "
from jupyter_server.auth import passwd
import json
import os

# 生成密码哈希
hashed_password = passwd('$NEW_PASSWORD')

# 创建配置目录
config_dir = os.path.expanduser('~/.jupyter')
os.makedirs(config_dir, exist_ok=True)

# 写入JSON配置（优先级高于.py配置）
config_file = os.path.join(config_dir, 'jupyter_server_config.json')
config = {
    'PasswordIdentityProvider': {
        'hashed_password': hashed_password
    },
    'ServerApp': {
        'ip': '0.0.0.0',
        'port': 8888,
        'allow_root': True,
        'open_browser': False,
        'token': '',
        'allow_origin': '*',
        'allow_remote_access': True,
        'disable_check_xsrf': True
    }
}

with open(config_file, 'w') as f:
    json.dump(config, f, indent=2)

print('Jupyter配置已更新到:', config_file)
"

if [ $? -eq 0 ]; then
    echo "✅ Jupyter Lab配置更新成功"
else
    echo "❌ Jupyter Lab配置更新失败"
fi

# 3. 更新VSCode Server配置
echo "3️⃣  更新VSCode Server配置..."
mkdir -p ~/.config/code-server

cat > ~/.config/code-server/config.yaml << EOF
bind-addr: 0.0.0.0:8080
auth: password
password: $NEW_PASSWORD
cert: false
EOF

if [ $? -eq 0 ]; then
    echo "✅ VSCode Server配置更新成功"
else
    echo "❌ VSCode Server配置更新失败"
fi

# 4. 重启服务
echo "4️⃣  重启相关服务..."

# 杀死现有进程
pkill -f "jupyter lab" 2>/dev/null
pkill -f "code-server" 2>/dev/null
sleep 2

# 重启Jupyter Lab (使用更新后的配置)
nohup jupyter lab --ip=0.0.0.0 --port=8888 --no-browser --allow-root > /tmp/jupyter.log 2>&1 &
JUPYTER_PID=$!

# 重启VSCode Server
nohup code-server > /tmp/code-server.log 2>&1 &
VSCODE_PID=$!

sleep 3

# 检查服务状态
if ps -p $JUPYTER_PID > /dev/null 2>&1; then
    echo "✅ Jupyter Lab已重启 (PID: $JUPYTER_PID)"
else
    echo "⚠️  Jupyter Lab重启可能失败，请检查日志: /tmp/jupyter.log"
fi

if ps -p $VSCODE_PID > /dev/null 2>&1; then
    echo "✅ VSCode Server已重启 (PID: $VSCODE_PID)"
else
    echo "⚠️  VSCode Server重启可能失败，请检查日志: /tmp/code-server.log"
fi

echo ""
echo "🎉 密码修改完成！"
echo ""
echo "📋 新密码适用于以下服务:"
echo "   - SSH登录"
echo "   - VSCode Server (端口8080)"
echo "   - Jupyter Lab (端口8888)"
echo ""
echo "💡 提示:"
echo "   - 新密码立即生效"
echo "   - 如果服务无法访问，请联系管理员"
echo "   - 日志文件位置:"
echo "     • Jupyter: /tmp/jupyter.log"
echo "     • VSCode: /tmp/code-server.log"
echo ""
echo "========================================"