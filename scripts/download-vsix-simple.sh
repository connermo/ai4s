#!/bin/bash

# 简化的VSIX下载脚本
#set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
VSIX_DIR="$PROJECT_ROOT/vsix-extensions"

echo "=== 简化VSIX下载脚本 ==="
echo "下载目录: $VSIX_DIR"

# 创建目录
mkdir -p "$VSIX_DIR"
cd "$VSIX_DIR"

# 扩展列表
extensions=(
    # Python开发核心
    "ms-python.python"
    "ms-toolsai.jupyter"
    "ms-python.pylint"
    "ms-python.black-formatter"
    "ms-python.isort"
    
    # 基础工具
    "ms-vscode.vscode-json"
    "redhat.vscode-yaml"
    "ms-vscode.vscode-git"
    "eamodio.gitlens"
    
    # 主题和图标
    "PKief.material-icon-theme"
    "zhuangtongfa.Material-theme"
    
    # 实用工具
    "streetsidesoftware.code-spell-checker"
)

successful=0
failed=0

for ext in "${extensions[@]}"; do
    echo ""
    echo "📥 下载扩展: $ext"
    
    # 使用curl直接下载（简化版本）
    url="https://marketplace.visualstudio.com/_apis/public/gallery/publishers/${ext%.*}/vsextensions/${ext#*.}/latest/vspackage"
    filename="${ext}-latest.vsix"
    
    if curl -L -o "$filename" "$url" --max-time 60; then
        echo "✅ 下载成功: $filename"
        ((successful++))
    else
        echo "❌ 下载失败: $ext"
        rm -f "$filename"
        ((failed++))
    fi
done

# 创建安装脚本
cat > "install-vsix.sh" << 'EOF'
#!/bin/bash
echo "=== VSIX扩展安装脚本 ==="
for vsix in *.vsix; do
    if [ -f "$vsix" ]; then
        echo "安装: $vsix"
        code-server --install-extension "$vsix" --force
    fi
done
echo "安装完成！"
EOF

chmod +x install-vsix.sh

echo ""
echo "🎉 下载完成！"
echo "成功: $successful, 失败: $failed"
echo "文件列表:"
ls -la *.vsix 2>/dev/null || echo "没有VSIX文件"
echo ""
echo "使用方法:"
echo "1. 复制到容器: docker cp vsix-extensions/ container:/tmp/"
echo "2. 在容器中运行: cd /tmp/vsix-extensions && ./install-vsix.sh"
