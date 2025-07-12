# GPU开发平台安装指南

## 系统要求

### 硬件要求
- CPU: 4核心以上
- 内存: 16GB以上（推荐32GB）
- 磁盘: 100GB可用空间
- GPU: NVIDIA GPU（可选，支持CUDA）

### 软件要求
- 操作系统: Ubuntu 18.04+ / CentOS 7+ / Debian 10+
- Docker: 20.10.0+
- Docker Compose: 1.29.0+
- NVIDIA Docker Runtime: 最新版本（GPU支持需要）

## 安装Docker

### Ubuntu/Debian
```bash
# 卸载旧版本
sudo apt-get remove docker docker-engine docker.io containerd runc

# 安装依赖
sudo apt-get update
sudo apt-get install ca-certificates curl gnupg lsb-release

# 添加Docker官方GPG密钥
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# 添加Docker仓库
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# 安装Docker
sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-compose-plugin

# 启动Docker服务
sudo systemctl start docker
sudo systemctl enable docker

# 添加用户到docker组
sudo usermod -aG docker $USER
```

### CentOS/RHEL
```bash
# 卸载旧版本
sudo yum remove docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine

# 安装yum-utils
sudo yum install -y yum-utils

# 添加Docker仓库
sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

# 安装Docker
sudo yum install docker-ce docker-ce-cli containerd.io docker-compose-plugin

# 启动Docker服务
sudo systemctl start docker
sudo systemctl enable docker

# 添加用户到docker组
sudo usermod -aG docker $USER
```

## 安装Docker Compose

```bash
# 下载Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/download/v2.12.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

# 设置可执行权限
sudo chmod +x /usr/local/bin/docker-compose

# 验证安装
docker-compose --version
```

## 安装NVIDIA Docker Runtime (GPU支持)

### Ubuntu/Debian
```bash
# 添加NVIDIA Docker仓库
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add -
curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | sudo tee /etc/apt/sources.list.d/nvidia-docker.list

# 安装nvidia-docker2
sudo apt-get update && sudo apt-get install -y nvidia-docker2

# 重启Docker服务
sudo systemctl restart docker
```

### CentOS/RHEL
```bash
# 添加NVIDIA Docker仓库
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.repo | sudo tee /etc/yum.repos.d/nvidia-docker.repo

# 安装nvidia-docker2
sudo yum install -y nvidia-docker2

# 重启Docker服务
sudo systemctl restart docker
```

## 验证安装

### 验证Docker
```bash
docker --version
docker run hello-world
```

### 验证Docker Compose
```bash
docker-compose --version
```

### 验证NVIDIA Docker Runtime
```bash
docker run --rm --gpus all nvidia/cuda:11.0-base nvidia-smi
```

## 防火墙配置

### Ubuntu (UFW)
```bash
# 允许管理端口
sudo ufw allow 8080/tcp

# 允许用户容器端口范围
sudo ufw allow 9000:9999/tcp

# 重新加载防火墙
sudo ufw reload
```

### CentOS (firewalld)
```bash
# 允许管理端口
sudo firewall-cmd --permanent --add-port=8080/tcp

# 允许用户容器端口范围
sudo firewall-cmd --permanent --add-port=9000-9999/tcp

# 重新加载防火墙
sudo firewall-cmd --reload
```

## 部署平台

1. **下载源码**
```bash
git clone <repository-url>
cd gpu-dev-platform
```

2. **设置权限**
```bash
chmod +x scripts/*.sh
```

3. **构建镜像**
```bash
./scripts/build.sh
```

4. **启动服务**
```bash
./scripts/start.sh
```

5. **验证部署**
- 访问 http://localhost:8080
- 使用默认账号 admin/admin123 登录

## 常见安装问题

### 1. Docker权限问题
```bash
# 如果遇到权限问题，重新登录或执行
newgrp docker
```

### 2. 端口冲突
```bash
# 检查端口占用
sudo netstat -tlnp | grep :8080

# 修改docker-compose.yml中的端口映射
```

### 3. GPU驱动问题
```bash
# 检查NVIDIA驱动
nvidia-smi

# 重新安装驱动
sudo apt-get install nvidia-driver-470
```

### 4. 磁盘空间不足
```bash
# 清理Docker镜像
docker system prune -a

# 检查磁盘使用
df -h
```

## 性能优化

### 1. Docker配置优化
编辑 `/etc/docker/daemon.json`:
```json
{
  "storage-driver": "overlay2",
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "default-runtime": "nvidia",
  "runtimes": {
    "nvidia": {
      "path": "/usr/bin/nvidia-container-runtime",
      "runtimeArgs": []
    }
  }
}
```

### 2. 系统内核参数调优
编辑 `/etc/sysctl.conf`:
```bash
# 网络优化
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 87380 134217728
net.ipv4.tcp_wmem = 4096 65536 134217728

# 应用配置
sysctl -p
```

## 备份与恢复

### 备份数据
```bash
# 备份数据库
cp platform.db platform.db.backup

# 备份用户数据
tar -czf users_backup.tar.gz users/

# 备份配置文件
tar -czf config_backup.tar.gz docker-compose.yml configs/
```

### 恢复数据
```bash
# 恢复数据库
cp platform.db.backup platform.db

# 恢复用户数据
tar -xzf users_backup.tar.gz

# 重启服务
./scripts/stop.sh
./scripts/start.sh
```

## 升级指南

1. **备份现有数据**
2. **下载新版本**
3. **停止服务**
```bash
./scripts/stop.sh
```
4. **重新构建镜像**
```bash
./scripts/build.sh
```
5. **启动服务**
```bash
./scripts/start.sh
```
6. **验证升级**

## 技术支持

如遇到安装问题，请提供以下信息：
- 操作系统版本
- Docker版本
- 错误日志
- 系统配置信息

联系方式：
- GitHub Issues: <repository-url>/issues
- 邮箱: support@example.com