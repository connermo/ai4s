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

try:
    with open(config_file, 'w') as f:
        json.dump(config, f, indent=2)
    print('Jupyter配置已更新到:', config_file)
except PermissionError:
    print('权限错误：无法写入Jupyter配置文件')
    exit(1)
except Exception as e:
    print('错误：', str(e))
    exit(1)
"

JUPYTER_UPDATE_STATUS=$?
if [ $JUPYTER_UPDATE_STATUS -eq 0 ]; then
    echo "✅ Jupyter Lab配置更新成功"
else
    echo "❌ Jupyter Lab配置更新失败（权限问题）"
    JUPYTER_UPDATE_FAILED=1
fi

# 3. 更新VSCode Server配置
echo "3️⃣  更新VSCode Server配置..."
mkdir -p ~/.config/code-server

if cat > ~/.config/code-server/config.yaml << EOF
bind-addr: 0.0.0.0:8080
auth: password
password: $NEW_PASSWORD
cert: false
EOF
then
    echo "✅ VSCode Server配置更新成功"
    VSCODE_UPDATE_STATUS=0
else
    echo "❌ VSCode Server配置更新失败（权限问题）"
    VSCODE_UPDATE_FAILED=1
    VSCODE_UPDATE_STATUS=1
fi

# 检查是否需要使用备用方案（通过API更新配置）
if [ "$JUPYTER_UPDATE_FAILED" = "1" ] || [ "$VSCODE_UPDATE_FAILED" = "1" ]; then
    echo ""
    echo "⚠️  检测到配置文件权限问题，尝试通过后端API更新配置..."
    
    # 尝试通过容器内部调用后端API（如果可用）
    # 这里可以添加API调用逻辑，但通常不建议从容器内部调用外部API
    echo "💡 提示：配置文件可能需要管理员权限来更新"
    echo "   请联系管理员或者重启容器以应用新的配置"
fi

# 4. 重启服务
echo "4️⃣  重启相关服务..."

# 更彻底地杀死现有进程
echo "正在停止现有服务..."

# 找到所有相关进程并强制杀死
JUPYTER_PIDS=$(pgrep -f "jupyter.*lab" | tr '\n' ' ')
VSCODE_PIDS=$(pgrep -f "code-server" | tr '\n' ' ')

if [ -n "$JUPYTER_PIDS" ]; then
    echo "停止Jupyter进程: $JUPYTER_PIDS"
    kill -TERM $JUPYTER_PIDS 2>/dev/null
    sleep 3
    # 如果还没停止，强制杀死
    for pid in $JUPYTER_PIDS; do
        if kill -0 $pid 2>/dev/null; then
            echo "强制停止Jupyter进程: $pid"
            kill -9 $pid 2>/dev/null
        fi
    done
fi

if [ -n "$VSCODE_PIDS" ]; then
    echo "停止VSCode进程: $VSCODE_PIDS"
    kill -TERM $VSCODE_PIDS 2>/dev/null
    sleep 3
    # 如果还没停止，强制杀死
    for pid in $VSCODE_PIDS; do
        if kill -0 $pid 2>/dev/null; then
            echo "强制停止VSCode进程: $pid"
            kill -9 $pid 2>/dev/null
        fi
    done
fi

sleep 2

# 清理Jupyter运行时缓存
rm -rf ~/.jupyter/runtime/* 2>/dev/null

# 重启Jupyter Lab (使用更新后的配置)
echo "正在启动Jupyter Lab..."
nohup jupyter lab --ip=0.0.0.0 --port=8888 --no-browser --allow-root > /tmp/jupyter.log 2>&1 &
JUPYTER_PID=$!

# 重启VSCode Server (使用配置文件中的密码)
echo "正在启动VSCode Server..."
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