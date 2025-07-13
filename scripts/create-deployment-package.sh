#!/bin/bash

# AI4S 部署包创建主脚本
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "=== AI4S 部署包创建工具 ==="
echo ""
echo "选择要创建的部署包类型:"
echo "1) 完整离线包 (包含所有Docker镜像，约6-8GB)"
echo "2) 快速部署包 (只包含源码，约50MB)"
echo "3) Docker镜像包 (只包含Docker镜像，约6-8GB)"
echo "4) 全部创建"
echo ""
read -p "请选择 [1-4]: " choice

case $choice in
    1)
        echo "🚀 创建完整离线部署包..."
        "$SCRIPT_DIR/build-offline-package.sh"
        ;;
    2)
        echo "🚀 创建快速部署包..."
        "$SCRIPT_DIR/quick-deploy.sh"
        ;;
    3)
        echo "🚀 创建Docker镜像包..."
        "$SCRIPT_DIR/prepare-offline-images.sh"
        ;;
    4)
        echo "🚀 创建所有部署包..."
        echo ""
        echo "1/3 创建Docker镜像包..."
        "$SCRIPT_DIR/prepare-offline-images.sh"
        echo ""
        echo "2/3 创建快速部署包..."
        "$SCRIPT_DIR/quick-deploy.sh"
        echo ""
        echo "3/3 创建完整离线包..."
        "$SCRIPT_DIR/build-offline-package.sh"
        echo ""
        echo "🎉 所有部署包创建完成！"
        ;;
    *)
        echo "❌ 无效选择"
        exit 1
        ;;
esac

echo ""
echo "📁 生成的文件:"
ls -lah "$PROJECT_ROOT"/*.tar.gz 2>/dev/null || echo "没有找到.tar.gz文件"
echo ""
echo "📖 部署指南:"
echo ""
echo "完整离线部署 (推荐无网络环境):"
echo "  1. 传输 ai4s-offline-*.tar.gz 到目标服务器"
echo "  2. tar -xzf ai4s-offline-*.tar.gz"
echo "  3. cd ai4s-offline-* && ./deploy.sh"
echo ""
echo "快速部署 (需要网络拉取基础镜像):"
echo "  1. 传输 ai4s-quick-*.tar.gz 到目标服务器"
echo "  2. tar -xzf ai4s-quick-*.tar.gz" 
echo "  3. cd ai4s-quick-* && ./quick-deploy.sh"
echo ""
echo "分步部署 (适合复杂环境):"
echo "  1. 先传输并加载镜像包: ai4s-docker-images-*.tar.gz"
echo "  2. 再传输快速部署包: ai4s-quick-*.tar.gz"
echo "  3. 运行 ./source-only-deploy.sh"
echo ""