# VSCode扩展VSIX离线包

这个包包含了常用的VSCode扩展的VSIX文件，可以在没有网络的环境中快速安装。

## 优势

- **速度快**: 直接从本地文件安装，无需网络下载
- **稳定性**: 版本固定，避免在线安装的版本冲突
- **离线友好**: 完全不依赖网络连接
- **批量操作**: 支持一键安装所有扩展

## 使用方法

### 安装所有扩展
```bash
./install-vsix.sh
```

### 安装单个扩展
```bash
code-server --install-extension xxx.vsix
```

### 卸载所有扩展
```bash
./uninstall-vsix.sh
```

### 查看扩展列表
```bash
cat extensions-manifest.txt
```

## 扩展类别

- **Python开发**: Python语言支持、Jupyter、代码检查等
- **基础工具**: JSON/YAML支持、Git集成等  
- **AI/ML工具**: GitHub Copilot、AI开发工具等
- **主题图标**: Material主题和图标
- **实用工具**: 拼写检查等

## 集成到容器

在Docker容器中使用:

```dockerfile
COPY vsix-extensions /tmp/vsix-extensions
RUN cd /tmp/vsix-extensions && ./install-vsix.sh
```

## 更新扩展

1. 在有网络的机器上运行下载脚本更新VSIX文件
2. 重新打包传输到目标环境
3. 卸载旧版本: `./uninstall-vsix.sh`
4. 安装新版本: `./install-vsix.sh`
