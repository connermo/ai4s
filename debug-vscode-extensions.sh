#!/bin/bash

# VSCode扩展调试脚本
# 用于检查插件安装状态和VSCode Server配置

echo "=== VSCode扩展调试脚本 ==="
echo ""

DEV_USER=${DEV_USER:-developer}

echo "🔍 环境信息:"
echo "用户: $DEV_USER"
echo "当前用户: $(whoami)"
echo "工作目录: $(pwd)"
echo ""

echo "📁 目录检查:"
echo "VSCode配置目录: $([ -d "/home/$DEV_USER/.config/code-server" ] && echo "✅ 存在" || echo "❌ 不存在")"
echo "扩展安装目录: $([ -d "/home/$DEV_USER/.local/share/code-server/extensions" ] && echo "✅ 存在" || echo "❌ 不存在")"
echo "预安装扩展目录: $([ -d "/tmp/extensions" ] && echo "✅ 存在" || echo "❌ 不存在")"
echo ""

echo "🔧 code-server命令检查:"
if command -v code-server &> /dev/null; then
    echo "✅ code-server命令可用"
    echo "版本: $(code-server --version | head -1)"
    echo "位置: $(which code-server)"
else
    echo "❌ code-server命令不可用"
fi
echo ""

echo "📋 配置文件检查:"
CONFIG_FILE="/home/$DEV_USER/.config/code-server/config.yaml"
if [ -f "$CONFIG_FILE" ]; then
    echo "✅ 配置文件存在: $CONFIG_FILE"
    echo "配置内容:"
    cat "$CONFIG_FILE" | sed 's/^/  /'
else
    echo "❌ 配置文件不存在: $CONFIG_FILE"
fi
echo ""

echo "📦 预安装扩展检查:"
if [ -d "/tmp/extensions" ]; then
    echo "预安装扩展目录内容:"
    ls -la /tmp/extensions/ | sed 's/^/  /'
    echo "扩展数量: $(ls /tmp/extensions/ 2>/dev/null | wc -l)"
else
    echo "❌ 预安装扩展目录不存在"
fi
echo ""

echo "🏠 用户扩展目录检查:"
USER_EXT_DIR="/home/$DEV_USER/.local/share/code-server/extensions"
if [ -d "$USER_EXT_DIR" ]; then
    echo "✅ 用户扩展目录存在"
    echo "目录内容:"
    ls -la "$USER_EXT_DIR" | sed 's/^/  /'
    echo "扩展数量: $(ls "$USER_EXT_DIR" 2>/dev/null | wc -l)"
    echo "目录权限: $(ls -ld "$USER_EXT_DIR")"
else
    echo "❌ 用户扩展目录不存在"
fi
echo ""

echo "🎯 已安装扩展列表:"
if command -v code-server &> /dev/null; then
    # 尝试列出已安装的扩展
    echo "通过code-server --list-extensions:"
    timeout 10 code-server --list-extensions 2>/dev/null | sed 's/^/  /' || echo "  ❌ 命令执行失败或超时"
    
    echo ""
    echo "通过目录扫描:"
    if [ -d "$USER_EXT_DIR" ]; then
        find "$USER_EXT_DIR" -maxdepth 1 -type d -name "*.*" | sed 's|.*/||' | sed 's/^/  /'
    else
        echo "  ❌ 扩展目录不存在"
    fi
else
    echo "❌ code-server命令不可用，无法列出扩展"
fi
echo ""

echo "🔗 进程检查:"
echo "code-server进程:"
pgrep -f code-server | while read pid; do
    echo "  PID: $pid"
    ps -p $pid -o pid,ppid,user,cmd | sed 's/^/    /'
done
echo ""

echo "📊 VSCode用户设置:"
SETTINGS_FILE="/home/$DEV_USER/.local/share/code-server/User/settings.json"
if [ -f "$SETTINGS_FILE" ]; then
    echo "✅ 用户设置文件存在"
    echo "设置内容:"
    cat "$SETTINGS_FILE" | sed 's/^/  /'
else
    echo "❌ 用户设置文件不存在: $SETTINGS_FILE"
fi
echo ""

echo "🌐 网络检查 (用于在线安装):"
if ping -c 1 marketplace.visualstudio.com > /dev/null 2>&1; then
    echo "✅ VSCode Marketplace连接正常"
else
    echo "⚠️  VSCode Marketplace连接失败"
fi
echo ""

echo "💡 建议操作:"
echo "1. 如果扩展目录为空，运行: cd /tmp/extensions && cp -r * /home/$DEV_USER/.local/share/code-server/extensions/"
echo "2. 如果权限有问题，运行: chown -R $DEV_USER:$DEV_USER /home/$DEV_USER/.local/share/code-server/"
echo "3. 重启VSCode Server: pkill code-server && code-server"
echo "4. 手动安装扩展: code-server --install-extension ms-python.python"
echo "5. 检查扩展: code-server --list-extensions"
echo ""