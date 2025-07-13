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
