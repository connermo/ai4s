# GPU开发平台 (AI4S)

基于GPU容器的多人开发平台，提供隔离的开发环境和统一的用户管理。

## 功能特性

1. **用户管理**: Golang Web界面，MySQL数据库存储
2. **GPU开发容器**: 集成VSCode Server、Jupyter Lab、SSH服务
3. **目录隔离**: 用户私有目录 + 共享只读/读写目录 + 组共享目录
4. **组管理**: 多级用户组织，支持组共享目录和权限管理
5. **端口管理**: 每用户独立端口分配，避免冲突
6. **GPU支持**: 基于NVIDIA CUDA，支持深度学习框架
7. **极简配置**: 只需配置一个数据根目录，其他自动生成

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

2. **一键配置和启动**
```bash
# 复制环境变量模板
cp .env.example .env

# 自动配置数据目录并启动服务
./scripts/setup-simple.sh
```

3. **访问管理界面**
- 地址: http://localhost:8080
- 默认管理员: admin / admin123

### 配置说明

**极简配置** - 只需要配置一个变量：

```bash
# .env 文件中的核心配置
DATA_ROOT="${PWD}/data"  # 数据根目录，其他目录自动生成
```

**自动生成的目录结构**：
```
${DATA_ROOT}/
├── users/          # 用户私有目录
├── shared-ro/      # 全局共享只读目录
├── shared-rw/      # 全局共享读写目录
└── groups/         # 组共享目录
```

**可选配置**：
```bash
# 端口配置（可选，有默认值）
DEFAULT_PORT_PREFIX=10000  # 用户端口起始前缀
PORT_STEP=10              # 每个用户的端口步长

# 数据库配置（可选，有默认值）
DB_DSN="platform:platform123@tcp(mysql:3306)/gpu_platform?charset=utf8mb4&parseTime=True&loc=Local"
PORT=8080

# Pip源配置（可选，用于加速Python包安装）
PIP_INDEX_URL=https://pypi.tuna.tsinghua.edu.cn/simple
PIP_TRUSTED_HOST=pypi.tuna.tsinghua.edu.cn
```

### 管理操作

**添加用户:**
1. 登录管理界面
2. 点击"添加用户"
3. 填写用户信息并创建

**创建开发容器:**
1. 选择用户
2. 配置GPU设备（可选）
3. 创建并启动容器

**组管理操作:**
1. 登录管理界面，点击"组管理"
2. 创建组：设置组名、描述和GID
3. 管理成员：添加/移除用户，分配角色（成员/管理员）
4. 用户容器将自动挂载所属组的共享目录

**用户服务访问:**
根据配置的 DEFAULT_PORT_PREFIX (默认10000) 和 PORT_STEP (默认10)：
- SSH: `ssh username@host -p {base_port+0}` (如10000, 10010, 10020...)
- VSCode: `http://host:{base_port+1}` (如10001, 10011, 10021...)
- Jupyter: `http://host:{base_port+2}` (如10002, 10012, 10022...)
- 备用应用端口: `http://host:{base_port+3}` 到 `{base_port+9}` (如10003-10009, 10013-10019...)

### 管理脚本

- `./scripts/setup-simple.sh` - 一键配置和启动
- `./scripts/start.sh` - 启动平台服务
- `./scripts/stop.sh` - 停止所有服务
- `./scripts/cleanup.sh` - 清理所有数据（谨慎使用）
- `./scripts/reset-database.sh` - 重置数据库（保留数据目录）
- `./scripts/reset-database-complete.sh` - 完全重置（包括数据目录）

### 测试验证

```bash
# 验证用户目录挂载
./tests/test-user-mount.sh

# 验证网站访问
./tests/test-website-access.sh
```

## 架构概述

```
ai4s/
├── backend/                 # Golang后端API服务
│   ├── main.go             # 主程序入口
│   ├── models/             # 数据库模型 (User, Container, Group)
│   ├── handlers/           # HTTP处理器 (含组管理API)
│   ├── services/           # 业务逻辑 (含组权限管理)
│   └── database/           # 数据库配置和迁移
├── frontend/               # Web前端界面
│   ├── templates/          # HTML模板 (含组管理界面)
│   └── static/             # 静态资源 (CSS/JS)
├── docker/                 # 容器配置
│   ├── Dockerfile.dev      # 开发容器镜像
│   └── entrypoint.sh       # 容器启动脚本 (含组权限设置)
├── scripts/                # 部署和管理脚本
├── tests/                  # 测试脚本
├── docs/                   # 文档目录
├── data/                   # 数据存储目录（自动生成）
│   ├── users/              # 用户隔离目录
│   ├── shared-ro/          # 共享目录(只读)
│   ├── shared-rw/          # 共享工作目录(读写)
│   └── groups/             # 组共享目录
└── docker-compose.yml      # 容器编排配置
```

## 服务端口分配

- **管理后台**: 8080
- **用户容器端口**: 10000-19999 (每用户分配10个端口)
  - SSH: 10000, 10010, 10020...
  - VSCode: 10001, 10011, 10021...
  - Jupyter: 10002, 10012, 10022...
  - 备用端口: 10003-10009, 10013-10019...

## 组管理系统

平台支持多级用户组织，提供组共享目录和权限管理功能。

### 组管理特性

1. **安全的GID分配**: 自动分配2000-65535范围的GID，避免系统冲突
2. **组共享目录**: 每个组拥有独立的共享目录，仅组成员可访问
3. **角色管理**: 支持组管理员和普通成员两种角色
4. **目录权限**: 基于Linux组权限的文件访问控制
5. **自动挂载**: 用户容器自动挂载所属组的共享目录

### 目录结构

用户容器内的目录布局：
- `~/` 或 `/home/username`: 个人主目录 (私有，读写)
- `~/shared-ro` 或 `/shared-ro`: 全局共享只读目录
- `~/shared-rw` 或 `/shared-rw`: 全局共享读写目录  
- `~/groups` 或 `/groups`: 组共享目录根目录
- `~/groups/<组名>/`: 组共享目录 (仅组成员可访问)
  - `~/groups/<组名>/shared-rw/`: 组协作工作区 (所有组成员可读写)
  - `~/groups/<组名>/shared-ro/`: 组资源目录 (管理员可写，成员只读)

### 使用示例

1. **创建研发组**：
   - 组名: `research`
   - 描述: `研发团队共享空间`
   - 添加成员: alice (管理员)、bob (成员)

2. **访问组目录**：
   ```bash
   # 进入组共享目录
   cd ~/groups/research
   ls  # 查看组目录结构: shared-rw/ shared-ro/
   
   # 协作工作区 (所有组成员可读写)
   cd ~/groups/research/shared-rw
   echo "team work" > project.txt
   
   # 资源目录 (管理员发布，成员只读)
   cd ~/groups/research/shared-ro
   ls -la  # 查看管理员发布的资源和配置
   ```

3. **权限说明**：
   - **组管理员**: 可管理组成员和设置，对shared-ro目录有写权限
   - **组成员**: 对shared-rw目录有读写权限，对shared-ro目录只读
   - **非成员**: 无法访问组共享目录

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

### 组管理

- `GET /api/groups` - 获取组列表
- `POST /api/groups` - 创建组
- `GET /api/groups/{id}` - 获取组详情
- `PUT /api/groups/{id}` - 更新组信息
- `DELETE /api/groups/{id}` - 删除组
- `GET /api/groups/{id}/members` - 获取组成员列表
- `POST /api/groups/{id}/members` - 添加组成员
- `PUT /api/groups/{id}/members/{userId}` - 更新成员角色
- `DELETE /api/groups/{id}/members/{userId}` - 移除组成员

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

4. **组共享目录无法访问**
   - 确认用户已加入对应组
   - 检查组目录权限设置 (应为775)
   - 验证容器内/groups目录是否存在
   - 检查GID分配是否有冲突
   
5. **组目录写权限问题**
   - 运行权限诊断: `./scripts/check-group-permissions.sh`
   - 自动修复权限: `./scripts/fix-group-permissions.sh`
   - 容器内测试写权限: `docker exec dev-username /app/scripts/test-group-write-permissions.sh`
   - 详细排查指南: 参见 `docs/group-permissions-troubleshooting.md`

6. **"bind source path does not exist" 错误**
   - 运行 `./scripts/setup-simple.sh` 重新配置
   - 检查 `DATA_ROOT` 路径是否正确
   - 确认目录权限设置正确
   - 详细指南: 参见 `docs/故障排除指南.md`

### 日志查看

```bash
# 查看平台后端日志
docker compose logs -f ai4s-platform

# 查看用户容器日志
docker logs dev-username

# 查看服务日志
docker exec dev-username tail -f /tmp/jupyter.log
docker exec dev-username tail -f /tmp/code-server.log

# 检查组目录挂载
docker exec dev-username ls -la /groups
docker exec dev-username ls -la /home/username/groups

# 检查用户组信息
docker exec dev-username id username
docker exec dev-username groups username
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

## 文档

详细文档请查看 `docs/` 目录：

- `docs/README.md` - 文档索引
- `docs/故障排除指南.md` - 常见问题解决方案
- `docs/配置简化演进总结.md` - 配置简化历程

## 许可证

本项目采用 MIT 许可证，详见 LICENSE 文件。
