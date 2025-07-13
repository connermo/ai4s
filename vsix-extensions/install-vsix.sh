#!/bin/bash
echo "=== VSIX扩展安装脚本 ==="
for vsix in *.vsix; do
    if [ -f "$vsix" ]; then
        echo "安装: $vsix"
        code-server --install-extension "$vsix" --force
    fi
done
echo "安装完成！"
