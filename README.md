# GPU开发平台 (AI4S)

基于GPU容器的多人开发平台，提供隔离的开发环境和统一的用户管理。

## 功能特性

1. **用户管理**: Golang Web界面，SQLite数据库存储
2. **GPU开发容器**: 集成VSCode Server、Jupyter Lab、TensorBoard、SSH服务
3. **目录隔离**: 用户私有目录 + 共享只读/读写目录
4. **端口管理**: 每用户独立端口分配，避免冲突
5. **GPU支持**: 基于NVIDIA CUDA，支持深度学习框架

## 快速开始

### 前置要求

- Docker >= 20.10
- Docker Compose >= 1.29
- NVIDIA Docker Runtime (用于GPU支持)
- 至少8GB内存和20GB磁盘空间

### 安装部署

1. **克隆项目**
```bash
git clone https://github.com/connermo/ai4s.git
cd ai4s
```

2. **配置环境变量**
```bash
# 复制环境变量模板
cp .env.example .env

# 根据需要修改 .env 文件中的配置：
# 1. 端口配置：
#    DEFAULT_PORT_PREFIX=9000  # 用户端口起始前缀
#    PORT_STEP=10             # 每个用户的端口步长 (占用10个端口)
# 2. 数据存储路径：
#    USERS_DATA_PATH=/your/data/path/users
#    SHARED_DATA_PATH=/your/data/path/shared  
#    WORKSPACE_DATA_PATH=/your/data/path/workspace
```

3. **创建数据目录**
```bash
# 根据 .env 文件中配置的路径创建目录
mkdir -p users shared workspace

# 或者如果使用自定义路径：
# mkdir -p /your/data/path/users
# mkdir -p /your/data/path/shared
# mkdir -p /your/data/path/workspace
```

4. **构建镜像**
```bash
./scripts/build.sh
```

5. **启动平台**
```bash
./scripts/start.sh
```

6. **访问管理界面**
- 地址: http://localhost:8080
- 默认管理员: admin / admin123

### 管理操作

**添加用户:**
1. 登录管理界面
2. 点击"添加用户"
3. 填写用户信息并创建

**创建开发容器:**
1. 选择用户
2. 配置GPU设备（可选）
3. 创建并启动容器

**用户服务访问:**
根据配置的 DEFAULT_PORT_PREFIX (默认9000) 和 PORT_STEP (默认10)：
- SSH: `ssh username@host -p {base_port+0}` (如9000, 9010, 9020...)
- VSCode: `http://host:{base_port+1}` (如9001, 9011, 9021...)
- Jupyter: `http://host:{base_port+2}` (如9002, 9012, 9022...)
- TensorBoard: `http://host:{base_port+3}` (如9003, 9013, 9023...)
- 备用应用端口: `http://host:{base_port+4}` 到 `{base_port+9}` (如9004-9009, 9014-9019...)

### 管理脚本

- `./scripts/build.sh` - 构建所有镜像
- `./scripts/start.sh` - 启动平台服务
- `./scripts/stop.sh` - 停止所有服务
- `./scripts/cleanup.sh` - 清理所有数据（谨慎使用）

## 架构概述

```
ai4s/
├── backend/                 # Golang后端API服务
│   ├── main.go             # 主程序入口
│   ├── models/             # 数据库模型
│   ├── handlers/           # HTTP处理器
│   ├── services/           # 业务逻辑
│   └── database/           # 数据库配置
├── frontend/               # Web前端界面
│   ├── templates/          # HTML模板
│   └── static/             # 静态资源
├── docker/                 # 容器配置
│   ├── Dockerfile.dev      # 开发容器镜像
│   └── entrypoint.sh       # 容器启动脚本
├── scripts/                # 部署和管理脚本
├── shared/                 # 共享目录(只读)
├── workspace/              # 共享工作目录(读写)
├── users/                  # 用户隔离目录
└── docker-compose.yml      # 容器编排配置
```

## 服务端口分配

- **管理后台**: 8080
- **用户容器端口**: 9000-9999 (每用户分配10个端口)
  - SSH: 900X
  - VSCode: 901X  
  - Jupyter: 902X
  - TensorBoard: 903X

## API文档

### 用户管理

- `GET /api/users` - 获取用户列表
- `POST /api/users` - 创建用户
- `GET /api/users/{id}` - 获取用户详情
- `PUT /api/users/{id}` - 更新用户信息
- `DELETE /api/users/{id}` - 删除用户
- `PUT /api/users/{id}/password` - 修改密码

### 容器管理

- `GET /api/containers` - 获取容器列表
- `POST /api/containers` - 创建容器
- `POST /api/containers/{id}/start` - 启动容器
- `POST /api/containers/{id}/stop` - 停止容器
- `DELETE /api/containers/{id}` - 删除容器

## 故障排除

### 常见问题

1. **容器无法启动**
   - 检查端口是否被占用
   - 确认用户目录权限正确
   - 查看容器日志

2. **GPU不可用**
   - 确认NVIDIA Docker Runtime已安装
   - 检查GPU设备权限
   - 验证CUDA驱动版本

3. **服务无法访问**
   - 确认防火墙设置
   - 检查端口映射配置
   - 验证网络连接

### 日志查看

```bash
# 查看平台后端日志
docker compose logs -f platform-backend

# 查看用户容器日志
docker logs dev-username

# 查看服务日志
docker exec dev-username tail -f /tmp/jupyter.log
```

## 安全注意事项

1. **修改默认密码**: 首次部署后立即修改管理员密码
2. **网络隔离**: 生产环境建议配置防火墙规则
3. **数据备份**: 定期备份用户数据和数据库
4. **权限控制**: 合理分配用户权限，避免权限过大

## 开发指南

### 开发环境设置

```bash
# 后端开发
cd backend
go mod tidy
go run main.go

# 前端开发
# 静态文件可直接编辑，无需额外构建步骤
```

### 自定义开发镜像

编辑 `docker/Dockerfile.dev` 添加所需软件包：

```dockerfile
# 添加新的Python包
RUN pip3 install your-package

# 添加系统工具
RUN apt-get update && apt-get install -y your-tool
```

## 许可证

本项目采用 MIT 许可证，详见 LICENSE 文件。
