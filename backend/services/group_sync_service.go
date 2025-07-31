package services

import (
	"context"
	"fmt"
	"log"
	"os"
	"strings"

	"github.com/docker/docker/api/types"
	"github.com/docker/docker/api/types/container"
	"github.com/docker/docker/client"
)

// GroupSyncService 处理用户组变更后的容器同步
type GroupSyncService struct {
	dockerClient *client.Client
}

// NewGroupSyncService 创建组同步服务
func NewGroupSyncService() (*GroupSyncService, error) {
	dockerClient, err := client.NewClientWithOpts(client.FromEnv)
	if err != nil {
		return nil, fmt.Errorf("failed to create Docker client: %v", err)
	}

	return &GroupSyncService{
		dockerClient: dockerClient,
	}, nil
}

// SyncUserContainerGroups 同步用户容器的组权限和挂载
func (s *GroupSyncService) SyncUserContainerGroups(username string, groups []string, groupGIDs []string) error {
	return s.SyncUserContainerGroupsWithRoles(username, groups, groupGIDs, nil)
}

// SyncUserContainerGroupsWithRoles 同步用户容器的组权限，支持角色信息
func (s *GroupSyncService) SyncUserContainerGroupsWithRoles(username string, groups []string, groupGIDs []string, roles []string) error {
	// 查找用户容器
	containerName := fmt.Sprintf("dev-%s", username)
	
	// 检查容器是否存在且运行中
	containers, err := s.dockerClient.ContainerList(context.Background(), types.ContainerListOptions{
		All: true,
	})
	if err != nil {
		return fmt.Errorf("failed to list containers: %v", err)
	}

	var targetContainer *types.Container
	for _, c := range containers {
		for _, name := range c.Names {
			if strings.TrimPrefix(name, "/") == containerName {
				targetContainer = &c
				break
			}
		}
		if targetContainer != nil {
			break
		}
	}

	if targetContainer == nil {
		log.Printf("容器 %s 不存在，跳过组同步", containerName)
		return nil
	}

	// 检查容器状态
	if targetContainer.State != "running" {
		log.Printf("容器 %s 未运行，跳过组同步", containerName)
		return nil
	}

	// 1. 更新容器内的用户组权限
	if err := s.updateContainerUserGroupsWithRoles(containerName, username, groups, groupGIDs, roles); err != nil {
		return fmt.Errorf("failed to update container user groups: %v", err)
	}

	// 2. 动态添加新的组目录挂载
	if err := s.updateContainerGroupMounts(containerName, username, groups); err != nil {
		return fmt.Errorf("failed to update container group mounts: %v", err)
	}

	// 3. 更新符号链接
	if err := s.updateContainerGroupLinks(containerName, username, groups); err != nil {
		return fmt.Errorf("failed to update container group links: %v", err)
	}

	log.Printf("成功同步用户 %s 的容器组权限", username)
	return nil
}

// updateContainerUserGroups 更新容器内用户的组权限（兼容性方法）
func (s *GroupSyncService) updateContainerUserGroups(containerName, username string, groups, groupGIDs []string) error {
	return s.updateContainerUserGroupsWithRoles(containerName, username, groups, groupGIDs, nil)
}

// updateContainerUserGroupsWithRoles 更新容器内用户的组权限，支持角色信息
func (s *GroupSyncService) updateContainerUserGroupsWithRoles(containerName, username string, groups, groupGIDs, roles []string) error {
	log.Printf("更新容器 %s 中用户 %s 的组权限", containerName, username)

	// 构建组管理脚本
	script := `#!/bin/bash
set -e

USERNAME="` + username + `"
USER_GROUPS="` + strings.Join(groups, ",") + `"
USER_GROUP_GIDS="` + strings.Join(groupGIDs, ",") + `"

echo "更新用户 $USERNAME 的组权限..."

# 将逗号分隔的字符串转换为数组
IFS=',' read -ra GROUP_NAMES <<< "$USER_GROUPS"
IFS=',' read -ra GROUP_GIDS <<< "$USER_GROUP_GIDS"

# 移除用户的所有组（除了主组）
CURRENT_GROUPS=$(groups $USERNAME | cut -d: -f2)
for group in $CURRENT_GROUPS; do
    if [ "$group" != "$USERNAME" ]; then
        gpasswd -d $USERNAME $group 2>/dev/null || true
    fi
done

# 为每个组创建系统组并将用户添加到组中
for i in "${!GROUP_NAMES[@]}"; do
    GROUP_NAME="${GROUP_NAMES[$i]}"
    GROUP_GID="${GROUP_GIDS[$i]}"
    
    echo "处理组: $GROUP_NAME (GID: $GROUP_GID)"
    
    # 创建系统组（如果不存在）
    if ! getent group "$GROUP_NAME" > /dev/null 2>&1; then
        groupadd -g "$GROUP_GID" "$GROUP_NAME" 2>/dev/null || true
        echo "  创建系统组: $GROUP_NAME ($GROUP_GID)"
    fi
    
    # 将用户添加到组中
    usermod -a -G "$GROUP_NAME" "$USERNAME" 2>/dev/null || true
    echo "  将用户 $USERNAME 添加到组 $GROUP_NAME"
    
    # 设置组目录权限（如果存在）
    GROUP_DIR="/groups/$GROUP_NAME"
    if [ -d "$GROUP_DIR" ]; then
        # 确保目录所有者是root，组是对应的组
        chown -R "root:$GROUP_NAME" "$GROUP_DIR" 2>/dev/null || true
        # 设置目录权限为775，确保组成员有写权限
        chmod -R 775 "$GROUP_DIR" 2>/dev/null || true
        # 设置组粘滞位，新文件继承组权限
        find "$GROUP_DIR" -type d -exec chmod g+s {} \; 2>/dev/null || true
        echo "  更新组目录权限: $GROUP_DIR (权限: $(ls -ld "$GROUP_DIR" 2>/dev/null | cut -d' ' -f1))"
    else
        # 如果目录不存在，创建它
        mkdir -p "$GROUP_DIR" 2>/dev/null || true
        chown "root:$GROUP_NAME" "$GROUP_DIR" 2>/dev/null || true
        chmod 775 "$GROUP_DIR" 2>/dev/null || true
        chmod g+s "$GROUP_DIR" 2>/dev/null || true
        echo "  创建组目录: $GROUP_DIR"
    fi
    
    # 创建标准子目录结构
    echo "  创建组子目录结构..."
    
    # shared-rw: 所有组成员可读写
    SHARED_RW_DIR="$GROUP_DIR/shared-rw"
    mkdir -p "$SHARED_RW_DIR" 2>/dev/null || true
    chown "root:$GROUP_NAME" "$SHARED_RW_DIR" 2>/dev/null || true
    chmod 775 "$SHARED_RW_DIR" 2>/dev/null || true
    chmod g+s "$SHARED_RW_DIR" 2>/dev/null || true
    echo "    ✓ 共享读写目录: shared-rw (775)"
    
    # shared-ro: 只有管理员可写，其他成员只读
    SHARED_RO_DIR="$GROUP_DIR/shared-ro"
    mkdir -p "$SHARED_RO_DIR" 2>/dev/null || true
    chown "root:$GROUP_NAME" "$SHARED_RO_DIR" 2>/dev/null || true
    chmod 755 "$SHARED_RO_DIR" 2>/dev/null || true
    chmod g+s "$SHARED_RO_DIR" 2>/dev/null || true
    echo "    ✓ 管理员专用目录: shared-ro (755)"
done


echo "用户组权限更新完成"
`

	// 在容器中执行脚本
	execConfig := types.ExecConfig{
		Cmd:          []string{"/bin/bash", "-c", script},
		AttachStdout: true,
		AttachStderr: true,
	}

	execID, err := s.dockerClient.ContainerExecCreate(context.Background(), containerName, execConfig)
	if err != nil {
		return fmt.Errorf("failed to create exec: %v", err)
	}

	err = s.dockerClient.ContainerExecStart(context.Background(), execID.ID, types.ExecStartCheck{})
	if err != nil {
		return fmt.Errorf("failed to start exec: %v", err)
	}

	return nil
}

// updateContainerGroupMounts 在容器内动态挂载组目录
func (s *GroupSyncService) updateContainerGroupMounts(containerName, username string, groups []string) error {
	log.Printf("更新容器 %s 中的组目录挂载", containerName)

	// 获取环境变量路径
	hostGroupsPath := os.Getenv("HOST_GROUPS_PATH")
	if hostGroupsPath == "" {
		hostGroupsPath = "./data/groups"
	}

	for _, groupName := range groups {
		hostGroupDir := fmt.Sprintf("%s/%s", hostGroupsPath, groupName)
		containerGroupDir := fmt.Sprintf("/groups/%s", groupName)
		
		// 确保宿主机组目录存在
		if err := os.MkdirAll(hostGroupDir, 0775); err != nil {
			log.Printf("警告: 无法创建组目录 %s: %v", hostGroupDir, err)
			continue
		}

		// 在容器内创建挂载点目录
		createDirScript := fmt.Sprintf(`
if [ ! -d "%s" ]; then
    mkdir -p "%s"
    echo "创建组目录: %s"
fi
`, containerGroupDir, containerGroupDir, containerGroupDir)

		execConfig := types.ExecConfig{
			Cmd:          []string{"/bin/bash", "-c", createDirScript},
			AttachStdout: true,
			AttachStderr: true,
		}

		execID, err := s.dockerClient.ContainerExecCreate(context.Background(), containerName, execConfig)
		if err != nil {
			log.Printf("警告: 无法在容器中创建目录 %s: %v", containerGroupDir, err)
			continue
		}

		err = s.dockerClient.ContainerExecStart(context.Background(), execID.ID, types.ExecStartCheck{})
		if err != nil {
			log.Printf("警告: 无法执行目录创建命令: %v", err)
			continue
		}

		// 注意：动态挂载需要特权容器或特殊配置
		// 目前通过目录创建和权限设置来实现，完整挂载需要重启容器
		log.Printf("组目录 %s 在容器内已创建，完整挂载需要重启容器", groupName)
	}

	return nil
}

// updateContainerGroupLinks 更新容器内的组目录符号链接
func (s *GroupSyncService) updateContainerGroupLinks(containerName, username string, groups []string) error {
	log.Printf("更新容器 %s 中用户 %s 的组目录符号链接", containerName, username)

	// 重建符号链接脚本
	script := fmt.Sprintf(`#!/bin/bash
USERNAME="%s"
USER_GROUPS="%s"

echo "更新用户目录下的组符号链接..."

# 移除旧的组符号链接（但保留 groups 主链接）
find "/home/$USERNAME" -maxdepth 1 -name "group-*" -type l -delete 2>/dev/null || true

# 确保 groups 主目录链接存在
if [ -d "/groups" ]; then
    ln -sfnT "/groups" "/home/$USERNAME/groups"
    chown -h $USERNAME:$USERNAME "/home/$USERNAME/groups"
    echo "  更新组目录主链接: ~/groups"
    
    # 列出可访问的组目录
    echo "  用户可访问的组目录:"
    IFS=',' read -ra GROUP_NAMES <<< "$USER_GROUPS"
    for GROUP_NAME in "${GROUP_NAMES[@]}"; do
        if [ -d "/groups/$GROUP_NAME" ]; then
            echo "    ~/groups/$GROUP_NAME"
        fi
    done
fi

echo "符号链接更新完成"
`, username, strings.Join(groups, ","))

	execConfig := types.ExecConfig{
		Cmd:          []string{"/bin/bash", "-c", script},
		AttachStdout: true,
		AttachStderr: true,
	}

	execID, err := s.dockerClient.ContainerExecCreate(context.Background(), containerName, execConfig)
	if err != nil {
		return fmt.Errorf("failed to create exec for links update: %v", err)
	}

	err = s.dockerClient.ContainerExecStart(context.Background(), execID.ID, types.ExecStartCheck{})
	if err != nil {
		return fmt.Errorf("failed to start exec for links update: %v", err)
	}

	return nil
}

// RestartUserContainer 重启用户容器以应用新的挂载配置
func (s *GroupSyncService) RestartUserContainer(username string) error {
	containerName := fmt.Sprintf("dev-%s", username)
	
	log.Printf("重启容器 %s 以应用新的组挂载配置", containerName)
	
	// 停止容器
	if err := s.dockerClient.ContainerStop(context.Background(), containerName, container.StopOptions{}); err != nil {
		return fmt.Errorf("failed to stop container: %v", err)
	}
	
	// 启动容器
	if err := s.dockerClient.ContainerStart(context.Background(), containerName, types.ContainerStartOptions{}); err != nil {
		return fmt.Errorf("failed to start container: %v", err)
	}
	
	log.Printf("容器 %s 重启完成", containerName)
	return nil
}

// NotifyContainerGroupChange 通知容器组权限发生变化，建议用户重新登录
func (s *GroupSyncService) NotifyContainerGroupChange(containerName, username string) error {
	script := fmt.Sprintf(`
echo "=== 组权限更新通知 ===" > /tmp/group_change_notice
echo "用户: %s" >> /tmp/group_change_notice
echo "时间: $(date)" >> /tmp/group_change_notice
echo "您的组权限已更新，建议重新登录SSH/VSCode以获得最新权限。" >> /tmp/group_change_notice
echo "新的组目录可通过 ~/groups/ 访问。" >> /tmp/group_change_notice
echo "=================================" >> /tmp/group_change_notice

# 如果用户正在使用终端，显示通知
if [ -n "$(who | grep %s)" ]; then
    wall "您的组权限已更新，建议重新登录以获得最新权限。详情请查看 /tmp/group_change_notice"
fi
`, username, username)

	execConfig := types.ExecConfig{
		Cmd:          []string{"/bin/bash", "-c", script},
		AttachStdout: true,
		AttachStderr: true,
	}

	execID, err := s.dockerClient.ContainerExecCreate(context.Background(), containerName, execConfig)
	if err != nil {
		return fmt.Errorf("failed to create notification exec: %v", err)
	}

	return s.dockerClient.ContainerExecStart(context.Background(), execID.ID, types.ExecStartCheck{})
}