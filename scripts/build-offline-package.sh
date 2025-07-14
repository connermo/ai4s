#!/bin/bash

# 离线部署包构建脚本
# 用于生成可在无网络环境下部署的完整包

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DIST_DIR="$PROJECT_ROOT/offline-dist"
PACKAGE_NAME="ai4s-offline-$(date +%Y%m%d-%H%M%S)"
BUILD_DIR="/tmp/$PACKAGE_NAME"
TARBALL_PATH="$DIST_DIR/${PACKAGE_NAME}.tar.gz"

echo "=== AI4S 离线部署包构建脚本 ==="
echo "项目根目录: $PROJECT_ROOT"
echo "输出目录: $DIST_DIR"
echo "构建目录: $BUILD_DIR"
echo "目标文件: $TARBALL_PATH"
echo ""

# 创建输出目录
echo "📁 创建输出目录..."
mkdir -p "$DIST_DIR"

# 检查Docker是否运行
if ! docker info > /dev/null 2>&1; then
    echo "❌ 错误: Docker未运行，请先启动Docker"
    exit 1
fi

# 检查pigz是否安装，并设置压缩工具
if command -v pigz &>/dev/null; then
    echo "🚀 使用 pigz 进行并行压缩"
    COMPRESS_CMD="pigz"
    TAR_COMPRESS_OPT="--use-compress-program=pigz"
else
    echo "⚠️  警告: pigz 未安装，将使用 gzip 进行压缩。如需加速，请安装pigz (e.g., sudo apt-get install pigz)"
    COMPRESS_CMD="gzip"
    TAR_COMPRESS_OPT="-z"
fi

# 创建构建目录
echo "📁 创建构建目录..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
mkdir -p "$BUILD_DIR/images"
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
    --exclude='.users' \
    --exclude='users' \
    --exclude='shared-ro' \
    --exclude='shared-rw' \
    --exclude='*.pyc'

# 构建Docker镜像
echo "🐳 构建Docker镜像..."
cd "$PROJECT_ROOT"

# 构建并标记后端镜像
echo "构建平台后端镜像..."
docker build -t connermo/ai4s-platform:latest -f backend/Dockerfile .

# 构建开发环境镜像
echo "构建GPU开发环境镜像..."
docker build -f docker/Dockerfile.dev -t connermo/ai4s-env:latest .

# 保存Docker镜像
echo "💾 导出Docker镜像..."
echo "导出平台后端镜像..."
docker save connermo/ai4s-platform:latest | $COMPRESS_CMD > "$BUILD_DIR/images/platform-backend.tar.gz"

echo "导出GPU开发环境镜像..."
docker save connermo/ai4s-env:latest | $COMPRESS_CMD > "$BUILD_DIR/images/ai4s-env.tar.gz"

# 导出依赖的基础镜像
echo "导出基础镜像..."
docker pull nvidia/cuda:12.4.1-cudnn-devel-ubuntu22.04
docker save nvidia/cuda:12.4.1-cudnn-devel-ubuntu22.04 | $COMPRESS_CMD > "$BUILD_DIR/images/nvidia-cuda-base.tar.gz"

# 导出MySQL镜像
echo "导出MySQL镜像..."
docker pull mysql:8.0
docker save mysql:8.0 | $COMPRESS_CMD > "$BUILD_DIR/images/mysql.tar.gz"

# 导出Nginx镜像
echo "导出Nginx镜像..."
docker pull nginx:alpine
docker save nginx:alpine | $COMPRESS_CMD > "$BUILD_DIR/images/nginx.tar.gz"

# 创建部署脚本
echo "📝 创建部署脚本..."
cat > "$BUILD_DIR/deploy.sh" << 'EOF'
#!/bin/bash

# AI4S 离线部署脚本
set -e

DEPLOY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$DEPLOY_DIR/source"
IMAGES_DIR="$DEPLOY_DIR/images"

echo "=== AI4S 离线部署脚本 ==="
echo "部署目录: $DEPLOY_DIR"
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

# 检查docker-compose
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo "❌ 错误: docker-compose未安装"
    exit 1
fi

# 导入Docker镜像
echo "🐳 导入Docker镜像..."
echo "导入NVIDIA CUDA基础镜像..."
docker load < "$IMAGES_DIR/nvidia-cuda-base.tar.gz"

echo "导入MySQL镜像..."
docker load < "$IMAGES_DIR/mysql.tar.gz"

echo "导入Nginx镜像..."
docker load < "$IMAGES_DIR/nginx.tar.gz"

echo "导入GPU开发环境镜像..."
docker load < "$IMAGES_DIR/ai4s-env.tar.gz"

echo "导入平台后端镜像..."
docker load < "$IMAGES_DIR/platform-backend.tar.gz"

# 复制项目文件到目标位置
TARGET_DIR="/opt/ai4s"
echo "📁 复制项目文件到 $TARGET_DIR..."
sudo mkdir -p "$TARGET_DIR"
sudo cp -r "$SOURCE_DIR"/* "$TARGET_DIR/"
sudo chown -R $USER:$USER "$TARGET_DIR"

# 进入项目目录
cd "$TARGET_DIR"

# 创建必要的目录
echo "📁 创建必要的目录..."
mkdir -p data/mysql
mkdir -p shared-ro
mkdir -p shared-rw
mkdir -p logs

# 设置权限
chmod 755 shared-ro shared-rw
chmod 777 data/mysql logs

# 创建.env文件
echo "⚙️ 创建环境配置..."
if [ ! -f .env ]; then
    cp .env.example .env
    echo "请根据需要修改 .env 文件中的配置"
    echo "" >> .env
    echo "# 用户容器使用的镜像" >> .env
    echo "USER_CONTAINER_IMAGE=connermo/ai4s-env:latest" >> .env
fi

# 检查NVIDIA驱动
echo "🔍 检查NVIDIA GPU支持..."
if command -v nvidia-smi &> /dev/null; then
    echo "✅ NVIDIA驱动已安装"
    nvidia-smi
else
    echo "⚠️  警告: 未检测到NVIDIA驱动，GPU功能可能不可用"
fi

# 检查nvidia-docker
if docker run --rm --gpus all nvidia/cuda:12.4.1-cudnn-devel-ubuntu22.04 nvidia-smi &> /dev/null; then
    echo "✅ Docker GPU支持正常"
else
    echo "⚠️  警告: Docker GPU支持可能有问题"
    echo "请确保已安装nvidia-docker2或nvidia-container-toolkit"
fi

echo ""
echo "🎉 部署完成！"
echo ""
echo "接下来的步骤："
echo "1. 检查并修改配置文件: $TARGET_DIR/.env"
echo "2. 启动服务: cd $TARGET_DIR && ./scripts/start.sh"
echo "3. 访问管理界面: http://服务器IP:端口/admin-login"
echo "4. 默认管理员账户: admin/admin123"
echo ""
echo "常用命令:"
echo "  启动服务: $TARGET_DIR/scripts/start.sh"
echo "  停止服务: $TARGET_DIR/scripts/stop.sh"
echo "  查看日志: docker-compose logs -f"
echo "  (镜像已预构建，如需重新构建请运行: docker-compose up --build -d)"
EOF

chmod +x "$BUILD_DIR/deploy.sh"

# 创建安装说明文档
cat > "$BUILD_DIR/README.md" << 'EOF'
# AI4S 离线部署包

这是一个完整的离线部署包，包含了AI4S GPU开发平台的所有组件和依赖。

## 系统要求

- Linux 操作系统 (推荐 Ubuntu 20.04+)
- Docker Engine 20.10+
- Docker Compose 2.0+
- NVIDIA GPU驱动 (如需GPU支持)
- nvidia-docker2 或 nvidia-container-toolkit

## 部署步骤

### 1. 解压部署包
```bash
tar -xzf ai4s-offline-*.tar.gz
cd ai4s-offline-*
```

### 2. 运行部署脚本
```bash
./deploy.sh
```

### 3. 配置环境变量
```bash
cd /opt/ai4s
# 根据需要修改 .env 文件
vim .env
```

### 4. 启动服务
```bash
./scripts/start.sh
```

### 5. 访问系统
- 管理界面: http://服务器IP:端口/admin-login
- 默认账户: admin/admin123

## 目录结构

```
/opt/ai4s/
├── backend/          # 后端Go代码
├── frontend/         # 前端静态文件
├── docker/          # Docker配置文件
├── configs/         # 配置文件
├── scripts/         # 启动脚本
├── data/           # 数据目录
│   └── mysql/      # MySQL数据
├── shared-ro/      # 只读共享目录
├── shared-rw/      # 读写工作区
└── logs/           # 日志目录
```

## 常用操作

### 服务管理
```bash
# 启动所有服务
./scripts/start.sh

# 停止所有服务
./scripts/stop.sh

# 查看服务状态
docker-compose ps

# 查看日志
docker-compose logs -f
```

### 用户容器管理
```bash
# 查看所有容器
docker ps -a

# 进入用户容器
docker exec -it <container-name> bash

# 查看容器日志
docker logs <container-name>
```

### 数据备份
```bash
# 备份MySQL数据
docker-compose exec mysql mysqldump -u root -p gpu_platform > backup.sql

# 备份用户数据
tar -czf user-data-backup.tar.gz shared-rw shared-ro
```

## 故障排除

### 1. GPU不可用
```bash
# 检查NVIDIA驱动
nvidia-smi

# 检查Docker GPU支持
docker run --rm --gpus all nvidia/cuda:12.4.1-cudnn-devel-ubuntu22.04 nvidia-smi
```

### 2. 端口冲突
修改 `.env` 文件中的端口配置，然后重启服务。

### 3. 权限问题
```bash
# 修复目录权限
sudo chown -R $USER:$USER /opt/ai4s
chmod 755 shared-ro shared-rw
chmod 777 data/mysql logs
```

### 4. 服务无法启动
```bash
# 查看详细日志
docker-compose logs

# 重新构建镜像
docker-compose up --build -d
```

## 升级

1. 停止服务: `./scripts/stop.sh`
2. 备份数据: `tar -czf backup-$(date +%Y%m%d).tar.gz data/`
3. 解压新版本部署包
4. 运行新的部署脚本
5. 恢复数据: `tar -xzf backup-*.tar.gz`
6. 启动服务: `./scripts/start.sh`

## 支持

如有问题，请检查：
1. 系统日志: `journalctl -f`
2. Docker日志: `docker-compose logs`
3. 应用日志: `tail -f logs/*.log`
EOF

# 创建版本信息文件
cat > "$BUILD_DIR/VERSION" << EOF
AI4S GPU开发平台 离线部署包
构建时间: $(date '+%Y-%m-%d %H:%M:%S')
构建主机: $(hostname)
Git版本: $(cd "$PROJECT_ROOT" && git rev-parse --short HEAD 2>/dev/null || echo "unknown")
包含组件:
- 平台后端镜像 (connermo/ai4s-platform:latest)
- GPU开发环境镜像 (connermo/ai4s-env:latest)
- MySQL 8.0
- Nginx Alpine
- 完整项目源码
EOF

echo_step "Step 3: 准备基础目录结构"
mkdir -p "$DIST_DIR/data"
mkdir -p "$DIST_DIR/scripts"

# 创建共享目录
echo_info "创建共享数据和工作区目录"
mkdir -p "$DIST_DIR/data/shared-ro"
mkdir -p "$DIST_DIR/data/shared-rw"
mkdir -p "$DIST_DIR/data/users"

# 设置基础权限
chmod 755 "$DIST_DIR/data/shared-ro"
chmod 777 "$DIST_DIR/data/shared-rw"
chmod 777 "$DIST_DIR/data/users"

# 复制脚本
cp scripts/start.sh scripts/stop.sh scripts/cleanup.sh "$DIST_DIR/scripts/"
chmod +x "$DIST_DIR"/scripts/*.sh

# 创建最终的tar包
echo "📦 创建最终部署包..."
cd "$(dirname "$BUILD_DIR")"
tar -c $TAR_COMPRESS_OPT -f "$TARBALL_PATH" "$PACKAGE_NAME"

# 清理临时目录
rm -rf "$BUILD_DIR"

# 显示结果
echo ""
echo "🎉 离线部署包构建完成！"
echo "📦 包文件: $TARBALL_PATH"
echo "📏 包大小: $(du -h "$TARBALL_PATH" | cut -f1)"
echo ""
echo "部署方法:"
echo "1. 将 $TARBALL_PATH 传输到目标服务器"
echo "2. 解压: tar -xzf $(basename "$TARBALL_PATH")"
echo "3. 运行: cd $(basename "$PACKAGE_NAME") && ./deploy.sh"
echo ""