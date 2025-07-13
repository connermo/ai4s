# AI4S GPU开发平台使用指南

## 快速开始

### 1. 登录和访问

管理员分配容器后，您将获得：
- SSH端口和密码
- VSCode Server端口
- Jupyter Lab端口

### 2. 开发环境概览

每个容器都预装了：
- **Python 3.11** + PyTorch 2.6.0 (主环境)
- **TensorFlow 2.15.0** (conda环境)
- **Jupyter Lab** 用于交互式开发
- **VSCode Server** 用于代码编写
- **Git** 用于版本控制

### 3. 目录结构

```
/home/developer/          # 个人主目录 (私有，可读写)
├── shared -> /shared     # 共享资源 (所有用户共享，只读)
├── workspace -> /workspace  # 工作空间 (所有用户共享，可读写)
└── README.md             # 容器使用说明

/shared/                  # 共享只读目录
├── datasets/            # 共享数据集
├── models/              # 预训练模型
├── scripts/             # 通用脚本
└── docs/                # 文档

/workspace/               # 共享工作空间
└── projects/            # 项目目录
```

## 开发工具使用

### SSH终端访问

```bash
ssh -p [您的SSH端口] developer@[服务器IP]
```

### VSCode Server

1. 在浏览器中访问分配的VSCode端口
2. 输入容器密码登录
3. 开始编程！

推荐插件会自动安装，包括：
- Python语言支持
- Jupyter Notebook集成
- Git工具
- 代码格式化工具

### Jupyter Lab

1. 在浏览器中访问分配的Jupyter端口
2. 输入容器密码登录
3. 创建新的Notebook开始实验

## 深度学习环境

### PyTorch环境（默认）

```bash
# 检查PyTorch版本
python3 -c "import torch; print(f'PyTorch: {torch.__version__}')"

# 检查GPU支持
python3 -c "import torch; print(f'CUDA可用: {torch.cuda.is_available()}')"

# 查看GPU信息
nvidia-smi
```

### TensorFlow环境（conda）

```bash
# 激活TensorFlow环境
conda activate tf
# 或者使用别名
tf

# 检查TensorFlow
python -c "import tensorflow as tf; print(f'TensorFlow: {tf.__version__}')"

# 退出环境
conda deactivate
# 或者使用别名
tfexit
```

## 常用命令和工具

### 文件管理

```bash
# 查看个人目录
ls ~/

# 查看共享资源
ls /shared/

# 查看工作空间
ls /workspace/

# 复制共享脚本到个人目录
cp /shared/scripts/example_utils.py ~/
```

### 开发工具

```bash
# Git配置
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"

# Python包管理
pip install package_name
pip list

# Conda环境管理
conda list
conda install package_name
```

### 系统监控

```bash
# GPU使用情况
nvidia-smi
gpuwatch  # 实时监控

# 系统资源
htop      # CPU和内存
df -h     # 磁盘空间
free -h   # 内存使用
```

## 最佳实践

### 1. 数据管理

- **个人数据**: 存放在 `~/` 目录下
- **共享数据**: 使用 `/shared/datasets/` 中的数据
- **项目协作**: 在 `/workspace/projects/` 下创建项目目录

### 2. 代码组织

```
~/my_project/
├── data/           # 个人数据
├── notebooks/      # Jupyter notebooks
├── src/           # 源代码
├── models/        # 训练的模型
├── results/       # 实验结果
└── requirements.txt
```

### 3. 环境管理

- 使用虚拟环境隔离依赖
- 记录依赖包版本
- 定期备份重要代码和数据

### 4. 资源使用

- 合理使用GPU资源
- 长时间运行的任务使用 `nohup` 或 `screen`
- 及时清理不需要的文件

## 示例工作流程

### 1. 新项目开始

```bash
# 创建项目目录
mkdir ~/my_project && cd ~/my_project

# 初始化Git仓库
git init

# 复制共享工具
cp /shared/scripts/example_utils.py src/

# 查看可用数据集
ls /shared/datasets/
```

### 2. 机器学习实验

```bash
# 使用共享工具
python3 -c "
from src.example_utils import get_gpu_info, setup_reproducible_training
print(get_gpu_info())
setup_reproducible_training(42)
"

# 训练模型
python train.py --data /shared/datasets/mnist/ --output models/
```

### 3. 结果分享

```bash
# 将结果放到工作空间供他人查看
cp -r results/ /workspace/projects/my_project_results/
```

## 故障排除

### 常见问题

1. **无法访问GPU**
   ```bash
   nvidia-smi  # 检查GPU状态
   python3 -c "import torch; print(torch.cuda.is_available())"
   ```

2. **磁盘空间不足**
   ```bash
   df -h       # 查看磁盘使用
   du -sh *    # 查看目录大小
   ```

3. **包安装失败**
   ```bash
   pip install --user package_name  # 安装到用户目录
   conda install package_name       # 使用conda安装
   ```

### 获取帮助

- 运行 `debug-vscode-extensions.sh` 检查VSCode插件状态
- 使用 `change-password` 修改密码
- 联系管理员获取技术支持

## 注意事项

1. **数据安全**: 重要数据请及时备份
2. **资源共享**: 合理使用共享资源，避免长时间占用
3. **密码安全**: 定期更改密码，不要共享账户
4. **系统更新**: 容器可能定期重建，请做好数据备份

---

如有问题或建议，请联系平台管理员。