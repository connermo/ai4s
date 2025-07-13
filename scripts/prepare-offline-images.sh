#!/bin/bash

# 准备离线Docker镜像脚本
# 在有网络的机器上运行，收集所有需要的Docker镜像

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
IMAGES_DIR="$PROJECT_ROOT/offline-images"
IMAGES_TARBALL="$PROJECT_ROOT/ai4s-docker-images-$(date +%Y%m%d-%H%M%S).tar.gz"

echo "=== AI4S Docker镜像离线准备脚本 ==="
echo "输出目录: $IMAGES_DIR"
echo "打包文件: $IMAGES_TARBALL"
echo ""

# 创建目录
mkdir -p "$IMAGES_DIR"
cd "$IMAGES_DIR"

# 定义需要的镜像列表
declare -a IMAGES=(
    "nvidia/cuda:12.4.1-cudnn-devel-ubuntu22.04"
    "mysql:8.0"
    "nginx:alpine"
)

echo "📥 拉取基础镜像..."
for image in "${IMAGES[@]}"; do
    echo "拉取: $image"
    docker pull "$image"
done

echo ""
echo "💾 导出镜像文件..."
for image in "${IMAGES[@]}"; do
    # 将镜像名称转换为文件名
    filename=$(echo "$image" | sed 's/[/:.]/-/g').tar.gz
    echo "导出: $image -> $filename"
    docker save "$image" | gzip > "$filename"
done

# 构建项目镜像
echo ""
echo "🐳 构建项目镜像..."
cd "$PROJECT_ROOT"
docker build -f docker/Dockerfile.dev -t gpu-dev-env:latest .

echo "导出项目镜像..."
docker save gpu-dev-env:latest | gzip > "$IMAGES_DIR/gpu-dev-env-latest.tar.gz"

# 创建加载脚本
cat > "$IMAGES_DIR/load-images.sh" << 'EOF'
#!/bin/bash

# Docker镜像加载脚本
set -e

IMAGES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== AI4S Docker镜像加载脚本 ==="
echo ""

# 检查Docker
if ! command -v docker &> /dev/null; then
    echo "❌ 错误: Docker未安装"
    exit 1
fi

if ! docker info > /dev/null 2>&1; then
    echo "❌ 错误: Docker未运行"
    exit 1
fi

echo "🐳 加载Docker镜像..."
cd "$IMAGES_DIR"

for tar_file in *.tar.gz; do
    if [ -f "$tar_file" ]; then
        echo "加载: $tar_file"
        docker load < "$tar_file"
    fi
done

echo ""
echo "✅ 所有镜像加载完成！"
echo ""
echo "已加载的镜像:"
docker images | grep -E "(nvidia/cuda|mysql|nginx|gpu-dev-env)"
EOF

chmod +x "$IMAGES_DIR/load-images.sh"

# 创建镜像清单
echo "📋 创建镜像清单..."
cat > "$IMAGES_DIR/images-manifest.txt" << EOF
AI4S Docker镜像清单
生成时间: $(date '+%Y-%m-%d %H:%M:%S')

基础镜像:
- nvidia/cuda:12.4.1-cudnn-devel-ubuntu22.04 (CUDA开发环境基础镜像)
- mysql:8.0 (数据库)
- nginx:alpine (Web服务器)

项目镜像:
- gpu-dev-env:latest (AI4S GPU开发环境)

文件说明:
$(ls -la *.tar.gz | awk '{print "- " $9 " (" $5 " bytes)"}')

总大小: $(du -sh . | cut -f1)

使用方法:
1. 将整个目录传输到目标服务器
2. 运行 ./load-images.sh 加载所有镜像
3. 验证: docker images
EOF

# 创建总的打包文件
echo "📦 创建镜像打包文件..."
cd "$PROJECT_ROOT"
tar -czf "$IMAGES_TARBALL" -C "$(dirname "$IMAGES_DIR")" "$(basename "$IMAGES_DIR")"

# 显示结果
echo ""
echo "🎉 Docker镜像离线包准备完成！"
echo ""
echo "📁 镜像目录: $IMAGES_DIR"
echo "📦 打包文件: $IMAGES_TARBALL"
echo "📏 总大小: $(du -sh "$IMAGES_TARBALL" | cut -f1)"
echo ""
echo "使用方法:"
echo "1. 传输到目标服务器: scp $IMAGES_TARBALL user@server:/tmp/"
echo "2. 解压: tar -xzf $(basename "$IMAGES_TARBALL")"
echo "3. 加载镜像: cd $(basename "$IMAGES_DIR") && ./load-images.sh"
echo ""
echo "镜像列表:"
for image in "${IMAGES[@]}"; do
    echo "  - $image"
done
echo "  - gpu-dev-env:latest"
echo ""