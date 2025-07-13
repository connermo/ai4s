#!/bin/bash

# VSCode扩展VSIX文件下载脚本
# 在有网络的机器上运行，下载VSIX文件用于离线安装

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
VSIX_DIR="$PROJECT_ROOT/vsix-extensions"
VSIX_TARBALL="$PROJECT_ROOT/ai4s-vsix-extensions-$(date +%Y%m%d-%H%M%S).tar.gz"

echo "=== VSCode扩展VSIX下载脚本 ==="
echo "下载目录: $VSIX_DIR"
echo "打包文件: $VSIX_TARBALL"
echo ""

# 创建VSIX目录
mkdir -p "$VSIX_DIR"
cd "$VSIX_DIR"

# 扩展列表
EXTENSIONS=(
    "ms-python.python"
    "ms-toolsai.jupyter"
    "ms-vscode.vscode-json"
    "redhat.vscode-yaml"
    "ms-python.pylint"
    "ms-python.black-formatter"
    "eamodio.gitlens"
    "PKief.material-icon-theme"
)

# 扩展描述
declare -A EXT_DESC=(
    ["ms-python.python"]="Python语言支持"
    ["ms-toolsai.jupyter"]="Jupyter Notebook支持"
    ["ms-vscode.vscode-json"]="JSON语言支持"
    ["redhat.vscode-yaml"]="YAML语言支持"
    ["ms-python.pylint"]="Python代码检查"
    ["ms-python.black-formatter"]="Python代码格式化"
    ["eamodio.gitlens"]="Git增强工具"
    ["PKief.material-icon-theme"]="Material图标主题"
)

# 下载函数
download_vsix() {
    local ext_id="$1"
    local description="$2"
    
    echo "📥 下载扩展: $ext_id ($description)"
    
    # 从marketplace获取最新版本信息
    local publisher="${ext_id%.*}"
    local extension="${ext_id#*.}"
    
    # 使用VSCode marketplace API获取下载链接
    local api_url="https://marketplace.visualstudio.com/_apis/public/gallery/extensionquery"
    local query_data='{
        "filters": [{
            "criteria": [{
                "filterType": 7,
                "value": "'$ext_id'"
            }],
            "pageNumber": 1,
            "pageSize": 1,
            "sortBy": 0,
            "sortOrder": 0
        }],
        "assetTypes": [],
        "flags": 914
    }'
    
    # 获取扩展信息
    local response=$(curl -s -X POST "$api_url" \
        -H "Content-Type: application/json" \
        -H "Accept: application/json;api-version=3.0-preview.1" \
        -d "$query_data" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    result = data['results'][0]['extensions'][0]
    version = result['versions'][0]['version']
    asset_uri = next(f['source'] for f in result['versions'][0]['files'] if f['assetType'] == 'Microsoft.VisualStudio.Services.VSIXPackage')
    print(f'{version}|{asset_uri}')
except:
    print('ERROR|')
    ")
    
    if [[ "$response" == "ERROR|"* ]]; then
        echo "⚠️  获取扩展信息失败: $ext_id"
        return 1
    fi
    
    local version="${response%|*}"
    local download_url="${response#*|}"
    local filename="${ext_id}-${version}.vsix"
    
    # 下载VSIX文件
    if curl -L -o "$filename" "$download_url"; then
        echo "✅ 下载成功: $filename"
        return 0
    else
        echo "❌ 下载失败: $ext_id"
        return 1
    fi
}

# 批量下载
echo "开始下载VSCode扩展..."
echo ""

successful_downloads=0
failed_downloads=0

for ext_id in "${EXTENSIONS[@]}"; do
    description="${EXT_DESC[$ext_id]:-$ext_id}"
    if download_vsix "$ext_id" "$description"; then
        ((successful_downloads++))
    else
        ((failed_downloads++))
    fi
    echo ""
    sleep 1  # 避免请求过于频繁
done

# 创建安装脚本
cat > "install-vsix.sh" << 'EOF'
#!/bin/bash

# VSIX扩展离线安装脚本
set -e

VSIX_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== VSCode扩展VSIX离线安装脚本 ==="
echo ""

# 检查code-server
if ! command -v code-server &> /dev/null; then
    echo "❌ 错误: code-server未找到"
    exit 1
fi

echo "📦 安装VSIX扩展..."
installed_count=0
failed_count=0

for vsix_file in *.vsix; do
    if [ -f "$vsix_file" ]; then
        echo "安装: $vsix_file"
        if timeout 60 code-server --install-extension "$vsix_file" --force; then
            echo "✅ 安装成功: $vsix_file"
            ((installed_count++))
        else
            echo "❌ 安装失败: $vsix_file"
            ((failed_count++))
        fi
        echo ""
    fi
done

echo "🎉 VSIX安装完成！"
echo "成功: $installed_count, 失败: $failed_count"
echo ""
echo "重新加载VSCode页面以查看新扩展"
EOF

chmod +x "install-vsix.sh"

# 创建卸载脚本
cat > "uninstall-vsix.sh" << 'EOF'
#!/bin/bash

# VSIX扩展卸载脚本
set -e

echo "=== VSCode扩展VSIX卸载脚本 ==="
echo ""

# 从文件名提取扩展ID
for vsix_file in *.vsix; do
    if [ -f "$vsix_file" ]; then
        # 提取扩展ID (去掉版本号和.vsix后缀)
        ext_id=$(echo "$vsix_file" | sed -E 's/-[0-9]+\.[0-9]+\.[0-9]+.*\.vsix$//')
        echo "卸载: $ext_id"
        code-server --uninstall-extension "$ext_id" || echo "卸载失败: $ext_id"
    fi
done

echo "🗑️  卸载完成！"
EOF

chmod +x "uninstall-vsix.sh"

# 创建扩展清单
cat > "extensions-manifest.txt" << EOF
VSCode扩展VSIX离线包
生成时间: $(date '+%Y-%m-%d %H:%M:%S')

下载统计:
- 成功下载: $successful_downloads 个扩展
- 下载失败: $failed_downloads 个扩展

扩展列表:
EOF

for ext_id in "${EXTENSIONS[@]}"; do
    description="${EXT_DESC[$ext_id]:-$ext_id}"
    vsix_files=(${ext_id}-*.vsix)
    if [ -f "${vsix_files[0]}" ]; then
        echo "✅ $ext_id - $description" >> "extensions-manifest.txt"
    else
        echo "❌ $ext_id - $description (下载失败)" >> "extensions-manifest.txt"
    fi
done

cat >> "extensions-manifest.txt" << EOF

文件说明:
$(ls -la *.vsix 2>/dev/null | awk '{print "- " $9 " (" $5 " bytes)"}' || echo "- 没有VSIX文件")

总大小: $(du -sh . | cut -f1)

使用方法:
1. 将整个目录传输到目标服务器
2. 运行 ./install-vsix.sh 安装所有扩展
3. 或手动安装: code-server --install-extension xxx.vsix
4. 卸载扩展: ./uninstall-vsix.sh

优势:
- 离线安装，不依赖网络
- 安装速度快，无需下载
- 版本固定，避免兼容性问题
- 支持批量安装和卸载
EOF

# 创建README文件
cat > "README.md" << 'EOF'
# VSCode扩展VSIX离线包

这个包包含了常用的VSCode扩展的VSIX文件，可以在没有网络的环境中快速安装。

## 优势

- **速度快**: 直接从本地文件安装，无需网络下载
- **稳定性**: 版本固定，避免在线安装的版本冲突
- **离线友好**: 完全不依赖网络连接
- **批量操作**: 支持一键安装所有扩展

## 使用方法

### 安装所有扩展
```bash
./install-vsix.sh
```

### 安装单个扩展
```bash
code-server --install-extension xxx.vsix
```

### 卸载所有扩展
```bash
./uninstall-vsix.sh
```

### 查看扩展列表
```bash
cat extensions-manifest.txt
```

## 扩展类别

- **Python开发**: Python语言支持、Jupyter、代码检查等
- **基础工具**: JSON/YAML支持、Git集成等  
- **AI/ML工具**: GitHub Copilot、AI开发工具等
- **主题图标**: Material主题和图标
- **实用工具**: 拼写检查等

## 集成到容器

在Docker容器中使用:

```dockerfile
COPY vsix-extensions /tmp/vsix-extensions
RUN cd /tmp/vsix-extensions && ./install-vsix.sh
```

## 更新扩展

1. 在有网络的机器上运行下载脚本更新VSIX文件
2. 重新打包传输到目标环境
3. 卸载旧版本: `./uninstall-vsix.sh`
4. 安装新版本: `./install-vsix.sh`
EOF

# 打包VSIX文件
echo "📦 创建VSIX扩展包..."
cd "$PROJECT_ROOT"
tar -czf "$VSIX_TARBALL" -C "$(dirname "$VSIX_DIR")" "$(basename "$VSIX_DIR")"

# 显示结果
echo ""
echo "🎉 VSIX扩展包创建完成！"
echo ""
echo "📁 扩展目录: $VSIX_DIR"
echo "📦 打包文件: $VSIX_TARBALL"
echo "📏 包大小: $(du -h "$VSIX_TARBALL" | cut -f1)"
echo ""
echo "下载统计:"
echo "✅ 成功: $successful_downloads 个扩展"
echo "❌ 失败: $failed_downloads 个扩展"
echo ""
echo "使用方法:"
echo "1. 传输到目标服务器: scp $VSIX_TARBALL user@server:/tmp/"
echo "2. 解压: tar -xzf $(basename "$VSIX_TARBALL")"
echo "3. 安装扩展: cd $(basename "$VSIX_DIR") && ./install-vsix.sh"
echo ""
echo "优势:"
echo "- 离线安装，速度极快"
echo "- 版本固定，避免兼容性问题"
echo "- 批量安装，操作简便"
echo ""