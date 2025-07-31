# 组共享目录权限问题排查指南

## 问题描述

用户反馈组成员对组共享目录没有写权限，无法在组目录中创建文件或文件夹。

## 快速诊断

### 1. 检查权限状态

```bash
# 检查宿主机和容器权限状态
./scripts/check-group-permissions.sh
```

### 2. 测试容器内写权限

```bash
# 在用户容器内测试写权限
docker exec dev-<用户名> /app/scripts/test-group-write-permissions.sh
```

## 权限修复

### 自动修复（推荐）

```bash
# 一键修复所有权限问题
./scripts/fix-group-permissions.sh
```

### 手动修复步骤

#### 1. 修复宿主机权限

```bash
# 进入项目目录
cd /path/to/ai4s

# 确保组目录存在且权限正确
mkdir -p data/groups
chmod 755 data/groups

# 修复每个组目录权限
for dir in data/groups/*/; do
    chmod -R 775 "$dir"
    echo "修复权限: $dir"
done
```

#### 2. 修复容器内权限

```bash
# 对每个运行中的用户容器执行
docker exec dev-<用户名> bash -c '
    # 确保组目录存在
    mkdir -p /groups
    
    # 修复每个组目录
    for group_dir in /groups/*/; do
        if [ -d "$group_dir" ]; then
            group_name=$(basename "$group_dir")
            echo "修复组目录: $group_name"
            
            # 设置正确的所有者和权限
            chown -R "root:$group_name" "$group_dir"
            chmod -R 775 "$group_dir"
            find "$group_dir" -type d -exec chmod g+s {} \;
        fi
    done
'
```

## 权限模型说明

### 正确的权限设置

- **宿主机目录**: `775` (rwxrwxr-x)
- **容器内目录**: `775` (rwxrwxr-x) + 组粘滞位 (g+s)
- **目录所有者**: `root:组名`

### 权限结构

```
/groups/
├── research-group/     (775, root:research-group, g+s)
│   ├── shared/         (775, root:research-group, g+s)
│   ├── projects/       (775, root:research-group, g+s)
│   └── resources/      (775, root:research-group, g+s)
└── dev-team/          (775, root:dev-team, g+s)
    ├── shared/         (775, root:dev-team, g+s)
    └── projects/       (775, root:dev-team, g+s)
```

## 常见问题和解决方案

### 问题1: "Permission denied" 错误

**症状**: 用户无法在组目录中创建文件

**原因**: 
- 目录权限不是775
- 用户不在对应的Linux组中
- 目录所有者设置错误

**解决方案**:
```bash
# 检查用户组成员身份
docker exec dev-<用户名> groups

# 检查目录权限
docker exec dev-<用户名> ls -la /groups/

# 运行修复脚本
./scripts/fix-group-permissions.sh
```

### 问题2: 新文件权限不正确

**症状**: 创建的文件其他组成员无法访问

**原因**: 目录没有设置组粘滞位 (g+s)

**解决方案**:
```bash
# 设置组粘滞位
docker exec dev-<用户名> bash -c '
    find /groups -type d -exec chmod g+s {} \;
'
```

### 问题3: 组目录不存在

**症状**: `/groups/<组名>` 目录不存在

**原因**: 
- 容器创建时组目录挂载失败
- 组目录创建时权限问题

**解决方案**:
```bash
# 重新创建并挂载组目录
./scripts/fix-group-permissions.sh

# 重启用户容器以重新挂载
docker restart dev-<用户名>
```

### 问题4: 宿主机权限错误

**症状**: 容器内权限正确但仍无法写入

**原因**: 宿主机目录权限限制了容器内访问

**解决方案**:
```bash
# 检查宿主机权限
ls -la data/groups/

# 修复宿主机权限
chmod -R 775 data/groups/*/
```

## 预防措施

### 1. 新建组时的权限设置

系统已自动处理权限设置，但可以手动验证：

```bash
# 创建组后检查权限
./scripts/check-group-permissions.sh
```

### 2. 添加组成员后的权限同步

系统会自动同步权限，但可以手动触发：

```bash
# 手动同步用户容器权限
docker exec dev-<用户名> bash -c 'groups' # 验证组成员身份
```

### 3. 定期权限检查

建议定期运行权限检查：

```bash
# 每周运行一次权限检查
./scripts/check-group-permissions.sh
```

## 权限验证清单

在修复权限后，请验证以下几点：

- [ ] 宿主机组目录权限为775
- [ ] 容器内组目录权限为775且有组粘滞位
- [ ] 用户已加入对应的Linux组
- [ ] 可以在组目录中创建文件
- [ ] 新创建的文件其他组成员可以访问
- [ ] 组目录符号链接 `~/groups` 存在且可访问

## 技术细节

### Linux组权限机制

- **775权限**: 所有者(rwx) + 组成员(rwx) + 其他用户(r-x)
- **组粘滞位(g+s)**: 新文件自动继承目录的组所有权
- **用户组成员身份**: 用户必须是Linux组的成员才能享有组权限

### Docker挂载机制

- 使用bind mount将宿主机目录挂载到容器
- 权限由宿主机目录权限和容器内权限共同决定
- UID/GID映射需要保持一致

### 动态权限同步

- 组成员变更时自动触发GroupSyncService
- 异步更新容器内用户组权限
- 无需重启容器即可生效