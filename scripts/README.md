# 管理脚本说明

本目录包含AI4S平台的管理和维护脚本。

## 部署脚本

- `build.sh` - 构建所有Docker镜像
- `start.sh` - 启动平台服务
- `stop.sh` - 停止所有服务  
- `cleanup.sh` - 清理所有数据（谨慎使用）

## 组权限管理脚本

### `check-group-permissions.sh`
**用途**: 检查组目录权限状态
**使用场景**: 诊断权限问题，验证权限设置

```bash
./scripts/check-group-permissions.sh
```

**输出内容**:
- 宿主机组目录权限
- 容器内组目录权限
- 用户组成员身份
- 权限问题诊断建议

### `fix-group-permissions.sh`
**用途**: 自动修复组目录权限问题
**使用场景**: 权限错误时的快速修复

```bash
./scripts/fix-group-permissions.sh
```

**修复内容**:
- 宿主机目录权限 (775)
- 容器内目录权限 (775 + g+s)
- 目录所有者设置 (root:组名)

### `test-group-write-permissions.sh`
**用途**: 在容器内测试组目录写权限
**使用场景**: 验证用户是否能正常写入组目录

```bash
# 在容器内运行
docker exec dev-username /app/scripts/test-group-write-permissions.sh
```

**测试内容**:
- 检查用户组成员身份
- 测试每个组目录的写权限
- 创建和删除测试文件

## 使用流程

### 日常维护检查

```bash
# 1. 检查权限状态
./scripts/check-group-permissions.sh

# 2. 如发现问题，运行修复
./scripts/fix-group-permissions.sh

# 3. 验证修复结果
./scripts/check-group-permissions.sh
```

### 权限问题排查

```bash
# 1. 用户反馈无法写入组目录
# 2. 运行诊断脚本
./scripts/check-group-permissions.sh

# 3. 在用户容器内测试
docker exec dev-<用户名> /app/scripts/test-group-write-permissions.sh

# 4. 修复权限问题
./scripts/fix-group-permissions.sh

# 5. 再次测试确认修复
docker exec dev-<用户名> /app/scripts/test-group-write-permissions.sh
```

### 新建组后验证

```bash
# 创建组后运行检查
./scripts/check-group-permissions.sh

# 如有问题立即修复
./scripts/fix-group-permissions.sh
```

## 注意事项

1. **权限修复脚本需要管理员权限**: 某些操作需要sudo权限
2. **容器必须运行中**: 容器内操作需要容器处于运行状态
3. **备份重要数据**: 在运行修复脚本前建议备份重要数据
4. **定期检查**: 建议每周运行一次权限检查脚本

## 故障排除

如果脚本执行失败，请检查：

1. Docker服务是否正常运行
2. 用户容器是否在运行状态
3. 脚本是否有执行权限 (`chmod +x script.sh`)
4. 宿主机是否有足够的磁盘空间

更详细的权限问题排查请参考: `docs/group-permissions-troubleshooting.md`