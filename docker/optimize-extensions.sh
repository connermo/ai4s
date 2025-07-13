#!/bin/bash

# VSCode Server 插件安装优化脚本
set -e

DEV_USER=${DEV_USER:-developer}

echo "=== VSCode Server 插件安装优化脚本 ==="
echo ""

# 检查网络连接
echo "🌐 检查网络连接..."
if ping -c 1 8.8.8.8 > /dev/null 2>&1; then
    echo "✅ 网络连接正常"
else
    echo "⚠️  网络连接可能有问题"
fi

# 检查DNS解析
echo "🔍 检查DNS解析..."
if nslookup marketplace.visualstudio.com > /dev/null 2>&1; then
    echo "✅ DNS解析正常"
else
    echo "⚠️  DNS解析可能有问题"
    echo "建议配置DNS: 8.8.8.8, 1.1.1.1"
fi

# 检查磁盘空间
echo "💾 检查磁盘空间..."
AVAILABLE_SPACE=$(df /home/$DEV_USER | awk 'NR==2 {print $4}')
if [ "$AVAILABLE_SPACE" -gt 1048576 ]; then  # 1GB
    echo "✅ 磁盘空间充足 ($(df -h /home/$DEV_USER | awk 'NR==2 {print $4}')可用)"
else
    echo "⚠️  磁盘空间不足，建议清理空间"
fi

# 优化扩展目录
echo "📁 优化扩展目录..."
EXTENSIONS_DIR="/home/$DEV_USER/.local/share/code-server/extensions"
mkdir -p "$EXTENSIONS_DIR"
chown -R $DEV_USER:$DEV_USER "$EXTENSIONS_DIR"
chmod 755 "$EXTENSIONS_DIR"

# 创建插件安装优化配置
echo "⚙️ 创建插件安装优化配置..."
cat > /home/$DEV_USER/.local/share/code-server/User/settings.json << 'EOF'
{
    "python.defaultInterpreterPath": "/usr/bin/python3",
    "python.terminal.activateEnvironment": true,
    "python.linting.enabled": true,
    "python.linting.pylintEnabled": true,
    "jupyter.askForKernelRestart": false,
    "jupyter.sendSelectionToInteractiveWindow": true,
    "terminal.integrated.shell.linux": "/bin/bash",
    "git.enableSmartCommit": true,
    "git.confirmSync": false,
    "workbench.startupEditor": "welcomePage",
    "extensions.autoUpdate": false,
    "extensions.autoCheckUpdates": false,
    "extensions.ignoreRecommendations": false,
    "update.mode": "none",
    "telemetry.telemetryLevel": "off",
    "http.proxyStrictSSL": false,
    "http.timeout": 60000,
    "extensions.gallery.timeout": 60000
}
EOF

chown $DEV_USER:$DEV_USER /home/$DEV_USER/.local/share/code-server/User/settings.json

# 创建快速安装脚本
echo "🚀 创建快速插件安装脚本..."
cat > /home/$DEV_USER/install-extensions.sh << 'EOF'
#!/bin/bash

# 快速安装常用VSCode插件
set -e

echo "=== 快速安装VSCode插件 ==="
echo ""

# 基础插件列表
BASIC_EXTENSIONS=(
    "ms-python.python"
    "ms-toolsai.jupyter" 
    "ms-vscode.vscode-json"
    "redhat.vscode-yaml"
    "ms-python.pylint"
    "ms-python.black-formatter"
)

# Python开发插件
PYTHON_EXTENSIONS=(
    "ms-python.isort"
    "ms-python.flake8"
    "charliermarsh.ruff"
    "ms-python.mypy-type-checker"
    "njpwerner.autodocstring"
)

# AI/ML插件
ML_EXTENSIONS=(
    "ms-toolsai.vscode-ai"
    "GitHub.copilot"
    "ms-python.debugpy"
)

# 工具插件
UTILITY_EXTENSIONS=(
    "eamodio.gitlens"
    "ms-vscode.vscode-git"
    "streetsidesoftware.code-spell-checker"
    "PKief.material-icon-theme"
    "zhuangtongfa.Material-theme"
)

install_extension() {
    local ext_id="$1"
    echo "安装插件: $ext_id"
    
    # 首先检查是否有VSIX文件可用
    local vsix_file="/tmp/vsix-extensions/${ext_id}-*.vsix"
    if ls $vsix_file 1> /dev/null 2>&1; then
        local actual_file=$(ls $vsix_file | head -1)
        echo "📦 使用VSIX文件安装: $(basename "$actual_file")"
        if timeout 60 code-server --install-extension "$actual_file" --force; then
            echo "✅ VSIX安装成功: $ext_id"
            return 0
        else
            echo "⚠️  VSIX安装失败，尝试在线安装: $ext_id"
        fi
    fi
    
    # 如果VSIX不可用或安装失败，尝试在线安装
    echo "🌐 在线安装: $ext_id"
    timeout 120 code-server --install-extension "$ext_id" || {
        echo "⚠️  插件 $ext_id 安装失败，跳过"
        return 1
    }
    
    echo "✅ 插件 $ext_id 安装成功"
    sleep 2  # 避免并发冲突
}

install_category() {
    local category="$1"
    shift
    local extensions=("$@")
    
    echo ""
    echo "📦 安装 $category 插件..."
    for ext in "${extensions[@]}"; do
        install_extension "$ext"
    done
}

# 交互式安装
echo "选择要安装的插件类型:"
echo "1) 基础插件 (Python, Jupyter, JSON, YAML等)"
echo "2) Python开发插件 (高级Python工具)"
echo "3) AI/ML插件 (Copilot, AI工具)" 
echo "4) 工具插件 (Git, 图标, 主题等)"
echo "5) 全部安装"
echo ""
read -p "请选择 [1-5]: " choice

case $choice in
    1)
        install_category "基础" "${BASIC_EXTENSIONS[@]}"
        ;;
    2)
        install_category "Python开发" "${PYTHON_EXTENSIONS[@]}"
        ;;
    3)
        install_category "AI/ML" "${ML_EXTENSIONS[@]}"
        ;;
    4)
        install_category "工具" "${UTILITY_EXTENSIONS[@]}"
        ;;
    5)
        install_category "基础" "${BASIC_EXTENSIONS[@]}"
        install_category "Python开发" "${PYTHON_EXTENSIONS[@]}"
        install_category "AI/ML" "${ML_EXTENSIONS[@]}"
        install_category "工具" "${UTILITY_EXTENSIONS[@]}"
        ;;
    *)
        echo "❌ 无效选择"
        exit 1
        ;;
esac

echo ""
echo "🎉 插件安装完成！"
echo "重新加载VSCode页面以看到新插件"
EOF

chmod +x /home/$DEV_USER/install-extensions.sh
chown $DEV_USER:$DEV_USER /home/$DEV_USER/install-extensions.sh

# 创建插件管理脚本
cat > /home/$DEV_USER/manage-extensions.sh << 'EOF'
#!/bin/bash

# VSCode插件管理脚本
set -e

show_help() {
    echo "VSCode插件管理工具"
    echo ""
    echo "用法: $0 [命令] [参数]"
    echo ""
    echo "命令:"
    echo "  list                列出已安装的插件"
    echo "  search <关键词>     搜索插件"
    echo "  install <插件ID>    安装插件"
    echo "  uninstall <插件ID>  卸载插件"
    echo "  update              更新所有插件"
    echo "  clean               清理插件缓存"
    echo "  backup              备份插件列表"
    echo "  restore             从备份恢复插件"
    echo ""
}

list_extensions() {
    echo "已安装的插件:"
    code-server --list-extensions | sort
}

search_extensions() {
    local keyword="$1"
    if [ -z "$keyword" ]; then
        echo "请提供搜索关键词"
        exit 1
    fi
    
    echo "搜索插件: $keyword"
    echo "提示: 请访问 https://marketplace.visualstudio.com/ 搜索"
}

install_extension() {
    local ext_id="$1"
    if [ -z "$ext_id" ]; then
        echo "请提供插件ID"
        exit 1
    fi
    
    echo "安装插件: $ext_id"
    timeout 120 code-server --install-extension "$ext_id"
}

uninstall_extension() {
    local ext_id="$1"
    if [ -z "$ext_id" ]; then
        echo "请提供插件ID"
        exit 1
    fi
    
    echo "卸载插件: $ext_id"
    code-server --uninstall-extension "$ext_id"
}

clean_cache() {
    echo "清理插件缓存..."
    rm -rf ~/.cache/code-server/
    rm -rf ~/.local/share/code-server/CachedExtensions/
    echo "缓存清理完成"
}

backup_extensions() {
    local backup_file="$HOME/vscode-extensions-backup-$(date +%Y%m%d-%H%M%S).txt"
    echo "备份插件列表到: $backup_file"
    code-server --list-extensions > "$backup_file"
    echo "备份完成"
}

restore_extensions() {
    local backup_file="$1"
    if [ -z "$backup_file" ]; then
        echo "用法: $0 restore <备份文件>"
        echo "可用的备份文件:"
        ls -la ~/vscode-extensions-backup-*.txt 2>/dev/null || echo "没有找到备份文件"
        exit 1
    fi
    
    if [ ! -f "$backup_file" ]; then
        echo "备份文件不存在: $backup_file"
        exit 1
    fi
    
    echo "从备份恢复插件: $backup_file"
    while IFS= read -r ext_id; do
        if [ -n "$ext_id" ]; then
            echo "安装: $ext_id"
            timeout 120 code-server --install-extension "$ext_id" || echo "跳过: $ext_id"
        fi
    done < "$backup_file"
    echo "恢复完成"
}

case "${1:-help}" in
    list)
        list_extensions
        ;;
    search)
        search_extensions "$2"
        ;;
    install)
        install_extension "$2"
        ;;
    uninstall)
        uninstall_extension "$2"
        ;;
    clean)
        clean_cache
        ;;
    backup)
        backup_extensions
        ;;
    restore)
        restore_extensions "$2"
        ;;
    help|*)
        show_help
        ;;
esac
EOF

chmod +x /home/$DEV_USER/manage-extensions.sh
chown $DEV_USER:$DEV_USER /home/$DEV_USER/manage-extensions.sh

echo ""
echo "🎉 VSCode Server 插件优化完成！"
echo ""
echo "可用工具:"
echo "  📦 快速安装: ~/install-extensions.sh"
echo "  🛠️  插件管理: ~/manage-extensions.sh"
echo ""
echo "VSIX离线安装:"
if [ -d "/tmp/vsix-extensions" ]; then
    echo "  📁 VSIX目录: /tmp/vsix-extensions"
    echo "  🚀 VSIX安装: cd /tmp/vsix-extensions && ./install-vsix.sh"
    echo "  📊 扩展数量: $(ls /tmp/vsix-extensions/*.vsix 2>/dev/null | wc -l) 个"
else
    echo "  📁 VSIX目录: 未找到 (将使用在线安装)"
fi
echo ""
echo "使用建议:"
echo "1. 优先使用VSIX离线安装 (速度最快)"
echo "2. VSIX不可用时自动降级到在线安装"
echo "3. 检查网络连接和DNS设置"
echo "4. 分批安装，避免并发冲突"
echo "5. 定期清理缓存提升性能"
echo ""