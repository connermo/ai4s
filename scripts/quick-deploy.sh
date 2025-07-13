#!/bin/bash

# AI4S 快速离线部署脚本 (适用于已有镜像的情况)
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
PACKAGE_NAME="ai4s-quick-$(date +%Y%m%d-%H%M%S)"
BUILD_DIR="/tmp/$PACKAGE_NAME"
TARBALL_PATH="$PROJECT_ROOT/${PACKAGE_NAME}.tar.gz"

echo "=== AI4S 快速离线部署包构建脚本 ==="
echo "注意: 此脚本假设目标服务器已有基础Docker镜像"
echo ""

# 创建构建目录
echo "📁 创建构建目录..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
mkdir -p "$BUILD_DIR/source"

# 复制项目源码
echo "📋 复制项目源码..."
rsync -av "$PROJECT_ROOT/" "$BUILD_DIR/source/" \
    --exclude='.git' \
    --exclude='node_modules' \
    --exclude='*.log' \
    --exclude='tmp' \
    --exclude='*.tar.gz' \
    --exclude='__pycache__' \
    --exclude='.DS_Store' \
    --exclude='*.pyc'

# 创建快速部署脚本
cat > "$BUILD_DIR/quick-deploy.sh" << 'EOF'
#!/bin/bash

# AI4S 快速部署脚本
set -e

DEPLOY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$DEPLOY_DIR/source"

echo "=== AI4S 快速部署脚本 ==="
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

# 复制项目文件
TARGET_DIR="/opt/ai4s"
echo "📁 部署项目文件到 $TARGET_DIR..."
sudo mkdir -p "$TARGET_DIR"
sudo cp -r "$SOURCE_DIR"/* "$TARGET_DIR/"
sudo chown -R $USER:$USER "$TARGET_DIR"

cd "$TARGET_DIR"

# 创建必要的目录
mkdir -p data/mysql data/shared data/workspace logs
chmod 755 data/shared data/workspace
chmod 777 data/mysql logs

# 创建.env文件
if [ ! -f .env ]; then
    cp .env.example .env
    echo "✅ 已创建 .env 配置文件"
fi

# 构建Docker镜像 (需要网络)
echo "🐳 构建Docker镜像..."
docker build -f docker/Dockerfile.dev -t gpu-dev-env:latest .

echo ""
echo "🎉 快速部署完成！"
echo ""
echo "接下来:"
echo "1. 配置: vim $TARGET_DIR/.env"
echo "2. 启动: cd $TARGET_DIR && ./scripts/start.sh"
echo "3. 访问: http://服务器IP:端口/admin-login"
EOF

chmod +x "$BUILD_DIR/quick-deploy.sh"

# 创建纯源码部署脚本
cat > "$BUILD_DIR/source-only-deploy.sh" << 'EOF'
#!/bin/bash

# AI4S 纯源码部署脚本 (需要手动构建镜像)
set -e

DEPLOY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$DEPLOY_DIR/source"
TARGET_DIR="/opt/ai4s"

echo "=== AI4S 纯源码部署脚本 ==="
echo ""

# 复制源码
echo "📁 部署源码到 $TARGET_DIR..."
sudo mkdir -p "$TARGET_DIR"
sudo cp -r "$SOURCE_DIR"/* "$TARGET_DIR/"
sudo chown -R $USER:$USER "$TARGET_DIR"

cd "$TARGET_DIR"

# 创建目录和配置
mkdir -p data/mysql data/shared data/workspace logs
chmod 755 data/shared data/workspace
chmod 777 data/mysql logs

if [ ! -f .env ]; then
    cp .env.example .env
fi

echo ""
echo "✅ 源码部署完成！"
echo ""
echo "手动构建步骤:"
echo "1. cd $TARGET_DIR"
echo "2. 修改配置: vim .env"
echo "3. 构建镜像: docker build -f docker/Dockerfile.dev -t gpu-dev-env:latest ."
echo "4. 启动服务: ./scripts/start.sh"
echo ""
EOF

chmod +x "$BUILD_DIR/source-only-deploy.sh"

# 创建说明文档
cat > "$BUILD_DIR/README.md" << 'EOF'
# AI4S 快速部署包

这是一个轻量级的部署包，只包含源码和部署脚本。

## 部署选项

### 选项1: 快速部署 (需要网络构建镜像)
```bash
./quick-deploy.sh
```

### 选项2: 纯源码部署 (手动构建)
```bash
./source-only-deploy.sh
```

## 系统要求

- Docker Engine 20.10+
- Docker Compose 2.0+
- NVIDIA GPU驱动 (可选)
- 网络连接 (仅用于拉取基础镜像)

## 基础镜像列表

如果服务器无网络，请预先拉取以下镜像:

```bash
# 核心镜像
docker pull nvidia/cuda:12.4.1-cudnn-devel-ubuntu22.04
docker pull mysql:8.0
docker pull nginx:alpine

# 保存镜像 (在有网络的机器上)
docker save nvidia/cuda:12.4.1-cudnn-devel-ubuntu22.04 | gzip > nvidia-cuda.tar.gz
docker save mysql:8.0 | gzip > mysql.tar.gz
docker save nginx:alpine | gzip > nginx.tar.gz

# 加载镜像 (在目标服务器上)
docker load < nvidia-cuda.tar.gz
docker load < mysql.tar.gz
docker load < nginx.tar.gz
```

## 离线环境部署

1. 在有网络的机器上准备镜像
2. 传输镜像文件到目标服务器
3. 加载镜像: `docker load < image.tar.gz`
4. 运行部署脚本: `./source-only-deploy.sh`
5. 手动构建: `docker build -f docker/Dockerfile.dev -t gpu-dev-env:latest .`
EOF

# 打包
echo "📦 创建快速部署包..."
cd "$(dirname "$BUILD_DIR")"
tar -czf "$TARBALL_PATH" "$PACKAGE_NAME"
rm -rf "$BUILD_DIR"

echo ""
echo "🎉 快速部署包构建完成！"
echo "📦 包文件: $TARBALL_PATH"
echo "📏 包大小: $(du -h "$TARBALL_PATH" | cut -f1)"
echo ""
echo "特点:"
echo "- 只包含源码，体积小"
echo "- 需要目标服务器有基础Docker镜像"
echo "- 适合快速更新和测试"
echo ""