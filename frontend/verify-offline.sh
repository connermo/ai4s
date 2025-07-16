#!/bin/bash

echo "🔍 验证前端本地化状态..."
echo "=================================="

# 检查必需的本地文件是否存在
echo "📁 检查必需的本地资源文件:"
files=(
    "static/css/bootstrap.min.css"
    "static/css/bootstrap-icons.css" 
    "static/css/admin.css"
    "static/js/bootstrap.bundle.min.js"
    "static/js/admin.js"
    "static/fonts/bootstrap-icons.woff2"
    "static/fonts/bootstrap-icons.woff"
)

all_exists=true
for file in "${files[@]}"; do
    if [ -f "$file" ]; then
        echo "✅ $file"
    else
        echo "❌ $file (缺失)"
        all_exists=false
    fi
done

echo ""
echo "🌐 检查外部CDN引用:"
# 检查HTML文件中的外部链接
external_links=$(find . -name "*.html" | xargs grep -n "https\?://" | grep -v "localhost\|127.0.0.1\|serverHost\|data:image" | wc -l)

if [ "$external_links" -eq 0 ]; then
    echo "✅ HTML文件中没有外部CDN链接"
else
    echo "❌ 发现 $external_links 个外部链接:"
    find . -name "*.html" | xargs grep -n "https\?://" | grep -v "localhost\|127.0.0.1\|serverHost\|data:image"
fi

echo ""
echo "📋 文件大小统计:"
for file in "${files[@]}"; do
    if [ -f "$file" ]; then
        size=$(du -h "$file" | cut -f1)
        echo "   $file: $size"
    fi
done

echo ""
if [ "$all_exists" = true ] && [ "$external_links" -eq 0 ]; then
    echo "🎉 前端已完全本地化！用户浏览器无需访问互联网即可正常使用。"
else
    echo "⚠️  前端本地化不完整，请检查上述问题。"
fi 