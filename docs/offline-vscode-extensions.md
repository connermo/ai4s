# VSCode扩展离线安装指南

## 🚫 离线环境限制

在没有互联网连接的服务器上，VSCode扩展无法在线安装。需要使用以下离线方法。

## 📦 方法一：使用VSIX文件（推荐）

### 1. 在有网络的机器上下载VSIX

运行我们提供的下载脚本：
```bash
./scripts/download-vsix.sh
```

这会创建包含常用扩展的离线包：`ai4s-vsix-extensions-*.tar.gz`

### 2. 传输到服务器

```bash
# 上传到服务器
scp ai4s-vsix-extensions-*.tar.gz user@server:/tmp/

# 在服务器上解压
cd /tmp && tar -xzf ai4s-vsix-extensions-*.tar.gz
```

### 3. 安装到容器

```bash
# 方法A：复制到容器的共享目录
cp -r vsix-extensions/ /path/to/ai4s/shared/

# 方法B：直接复制到容器
docker cp vsix-extensions/ container_name:/tmp/vsix-extensions/
```

### 4. 在容器中安装

```bash
# SSH登录到容器后
cd /tmp/vsix-extensions
./install-vsix.sh

# 或手动安装单个扩展
code-server --install-extension extension.vsix
```

## 🔧 方法二：手动下载和安装

### 1. 手动下载扩展

访问 https://marketplace.visualstudio.com/ 搜索扩展，点击"Download Extension"下载VSIX文件。

### 2. 常用扩展列表

```bash
# Python开发
ms-python.python
ms-toolsai.jupyter
ms-python.pylint
ms-python.black-formatter

# 基础工具
ms-vscode.vscode-json
redhat.vscode-yaml
eamodio.gitlens

# 主题和图标
PKief.material-icon-theme
zhuangtongfa.Material-theme
```

### 3. 安装命令

```bash
# 在容器中执行
code-server --install-extension /path/to/extension.vsix
```

## 📁 方法三：预构建包含扩展的镜像

### 1. 在有网络的环境构建

修改Dockerfile.dev，在构建时下载扩展：

```dockerfile
# 在有网络的机器上构建时添加
RUN mkdir -p /tmp/extensions \
    && code-server --install-extension ms-python.python --extensions-dir /tmp/extensions \
    && code-server --install-extension ms-toolsai.jupyter --extensions-dir /tmp/extensions \
    && chmod -R 755 /tmp/extensions
```

### 2. 导出和导入镜像

```bash
# 导出镜像
docker save gpu-dev-env:latest | gzip > gpu-dev-env-with-extensions.tar.gz

# 传输到离线服务器并导入
docker load < gpu-dev-env-with-extensions.tar.gz
```

## 🛠️ 方法四：使用共享目录

### 1. 准备扩展包

在有网络的机器上：
```bash
# 创建扩展包
mkdir -p shared/vscode-extensions
cd shared/vscode-extensions

# 下载扩展VSIX文件
# 或使用我们的下载脚本
../../scripts/download-vsix.sh
cp vsix-extensions/*.vsix ./
```

### 2. 在容器中安装

```bash
# 容器启动后，扩展在 /shared/vscode-extensions/ 目录
ls /shared/vscode-extensions/

# 批量安装
for vsix in /shared/vscode-extensions/*.vsix; do
    code-server --install-extension "$vsix" --force
done
```

## 🔍 验证安装

```bash
# 列出已安装扩展
code-server --list-extensions

# 检查扩展目录
ls ~/.local/share/code-server/extensions/

# 重启VSCode Server
pkill code-server && nohup code-server > /tmp/code-server.log 2>&1 &
```

## 💡 最佳实践

1. **使用VSIX下载脚本**：我们提供的脚本会下载常用扩展
2. **预准备扩展包**：在有网络时准备好离线包
3. **版本管理**：记录扩展版本避免兼容性问题
4. **批量安装**：使用脚本批量安装避免重复操作

## 🚨 注意事项

- 某些扩展可能依赖网络服务（如GitHub Copilot）
- 扩展更新需要重新下载VSIX文件
- 确保VSIX文件版本与code-server版本兼容
- 离线环境中无法使用扩展的在线功能