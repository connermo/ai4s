package services

import (
	"context"
	"database/sql"
	"fmt"
	"os"
	"strconv"
	"strings"
	"time"

	"gpu-dev-platform/database"
	"gpu-dev-platform/models"
	"github.com/docker/docker/api/types"
	"github.com/docker/docker/api/types/container"
	"github.com/docker/docker/api/types/mount"
	"github.com/docker/docker/client"
	"github.com/docker/go-connections/nat"
)

var userContainerImage = "connermo/ai4s-env:latest"

func init() {
	if img := os.Getenv("USER_CONTAINER_IMAGE"); img != "" {
		userContainerImage = img
	}
}

type ContainerService struct {
	db           *sql.DB
	dockerClient *client.Client
}

// 辅助函数：获取环境变量，如果不存在则返回默认值
func getEnvWithDefault(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

func NewContainerService() (*ContainerService, error) {
	cli, err := client.NewClientWithOpts(client.FromEnv, client.WithAPIVersionNegotiation())
	if err != nil {
		return nil, err
	}

	return &ContainerService{
		db:           database.DB,
		dockerClient: cli,
	}, nil
}

func (s *ContainerService) CreateContainer(user *models.User, gpuDevices string) (*models.Container, error) {
	return s.CreateContainerWithPassword(user, gpuDevices, "defaultpass")
}

func (s *ContainerService) CreateContainerWithPassword(user *models.User, gpuDevices, password string) (*models.Container, error) {
	containerName := fmt.Sprintf("dev-%s", user.Username)
	
	// 创建容器配置
	config := &container.Config{
		Image: userContainerImage,
		// 不设置User，让容器以root启动确保SSH服务可以运行
		Env: []string{
			fmt.Sprintf("DEV_USER=%s", user.Username),
			fmt.Sprintf("DEV_UID=%d", user.ID+1000),
			fmt.Sprintf("DEV_GID=%d", user.ID+1000),
			fmt.Sprintf("DEV_PASSWORD=%s", password), // 使用传入的密码
			// Pip源配置
			fmt.Sprintf("PIP_INDEX_URL=%s", os.Getenv("PIP_INDEX_URL")),
			fmt.Sprintf("PIP_TRUSTED_HOST=%s", os.Getenv("PIP_TRUSTED_HOST")),
			fmt.Sprintf("PIP_TIMEOUT=%s", getEnvWithDefault("PIP_TIMEOUT", "60")),
		},
		ExposedPorts: s.getExposedPorts(user),
	}

	// 从环境变量获取路径配置
	usersDataPath := os.Getenv("USERS_DATA_PATH")
	if usersDataPath == "" {
		usersDataPath = "/app/users"
	}
	
	sharedDataPath := os.Getenv("SHARED_DATA_PATH")
	if sharedDataPath == "" {
		sharedDataPath = "/app/shared"
	}
	
	workspaceDataPath := os.Getenv("WORKSPACE_DATA_PATH")
	if workspaceDataPath == "" {
		workspaceDataPath = "/shared-rw"
	}
	
	containerHomePath := os.Getenv("CONTAINER_HOME_PATH")
	if containerHomePath == "" {
		containerHomePath = "/home"
	}
	
	containerSharedPath := os.Getenv("CONTAINER_SHARED_RO_PATH")
	if containerSharedPath == "" {
		containerSharedPath = "/shared"
	}
	
	containerWorkspacePath := os.Getenv("CONTAINER_SHARED_RW_PATH")
	if containerWorkspacePath == "" {
		containerWorkspacePath = "/workspace"
	}

	// 创建用户目录（如果不存在）
	userDir := fmt.Sprintf("%s/%s", usersDataPath, user.Username)
	os.MkdirAll(userDir, 0755)
	os.MkdirAll(sharedDataPath, 0755)  
	os.MkdirAll(workspaceDataPath, 0755)

	// 从环境变量获取宿主机绝对路径
	hostSharedPath := os.Getenv("HOST_SHARED_RO_PATH")
	if hostSharedPath == "" {
		return nil, fmt.Errorf("HOST_SHARED_RO_PATH environment variable not set")
	}
	
	hostWorkspacePath := os.Getenv("HOST_SHARED_RW_PATH")
	if hostWorkspacePath == "" {
		return nil, fmt.Errorf("HOST_SHARED_RW_PATH environment variable not set")
	}
	
	hostUsersPath := os.Getenv("HOST_USERS_PATH")
	if hostUsersPath == "" {
		return nil, fmt.Errorf("HOST_USERS_PATH environment variable not set")
	}
	
	hostUserDir := fmt.Sprintf("%s/%s", hostUsersPath, user.Username)

	hostConfig := &container.HostConfig{
		PortBindings: s.getPortBindings(user),
		Mounts: []mount.Mount{
			{
				Type:   mount.TypeBind,
				Source: hostUserDir,
				Target: containerHomePath,
			},
			{
				Type:     mount.TypeBind,
				Source:   hostSharedPath,
				Target:   containerSharedPath,
				ReadOnly: true,
			},
			{
				Type:   mount.TypeBind,
				Source: hostWorkspacePath,
				Target: containerWorkspacePath,
			},
		},
		Resources: container.Resources{},
		RestartPolicy: container.RestartPolicy{
			Name: "unless-stopped",
		},
	}

	// 如果有GPU设备，添加GPU配置
	if gpuDevices != "" {
		// 解析GPU设备ID
		deviceIDs := []string{}
		if gpuDevices != "all" {
			// 分割逗号分隔的设备ID
			for _, id := range strings.Split(gpuDevices, ",") {
				deviceIDs = append(deviceIDs, strings.TrimSpace(id))
			}
		}
		
		deviceRequest := container.DeviceRequest{
				Driver:       "nvidia",
				Capabilities: [][]string{{"gpu"}},
		}
		
		if len(deviceIDs) > 0 {
			// 指定特定GPU设备
			deviceRequest.DeviceIDs = deviceIDs
		} else {
			// 使用所有GPU
			deviceRequest.Count = -1
		}
		
		hostConfig.DeviceRequests = []container.DeviceRequest{deviceRequest}
	}

	// 创建容器
	resp, err := s.dockerClient.ContainerCreate(
		context.Background(),
		config,
		hostConfig,
		nil,
		nil,
		containerName,
	)
	if err != nil {
		return nil, err
	}

	// 保存到数据库
	cont := &models.Container{
		ID:          resp.ID,
		UserID:      user.ID,
		Name:        containerName,
		Status:      "created",
		ImageName:   userContainerImage,
		CPULimit:    "unlimited",
		MemoryLimit: "unlimited",
		GPUDevices:  gpuDevices,
		CreatedAt:   time.Now(),
		UpdatedAt:   time.Now(),
		LastSeen:    time.Now(),
	}

	query := `
		INSERT INTO containers (id, user_id, name, status, image_name, cpu_limit, memory_limit, gpu_devices, created_at, updated_at, last_seen)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
	`
	
	_, err = s.db.Exec(query, cont.ID, cont.UserID, cont.Name, cont.Status,
		cont.ImageName, cont.CPULimit, cont.MemoryLimit, cont.GPUDevices,
		cont.CreatedAt, cont.UpdatedAt, cont.LastSeen)
	if err != nil {
		return nil, err
	}

	// 更新用户的容器ID
	_, err = s.db.Exec("UPDATE users SET container_id = ? WHERE id = ?", 
		cont.ID, user.ID)
	if err != nil {
		return nil, err
	}

	// 自动启动容器
	if err = s.StartContainer(cont.ID); err != nil {
		return nil, fmt.Errorf("容器创建成功但启动失败: %v", err)
	}

	// 更新状态为运行中
	cont.Status = "running"

	return cont, nil
}

func (s *ContainerService) StartContainer(containerID string) error {
	err := s.dockerClient.ContainerStart(context.Background(), containerID, types.ContainerStartOptions{})
	if err != nil {
		return err
	}

	// 更新状态
	_, err = s.db.Exec("UPDATE containers SET status = ?, updated_at = ? WHERE id = ?",
		"running", time.Now(), containerID)
	return err
}

func (s *ContainerService) StopContainer(containerID string) error {
	timeout := 30
	err := s.dockerClient.ContainerStop(context.Background(), containerID, 
		container.StopOptions{Timeout: &timeout})
	if err != nil {
		return err
	}

	// 更新状态
	_, err = s.db.Exec("UPDATE containers SET status = ?, updated_at = ? WHERE id = ?",
		"stopped", time.Now(), containerID)
	return err
}

func (s *ContainerService) RemoveContainer(containerID string) error {
	err := s.dockerClient.ContainerRemove(context.Background(), containerID, 
		types.ContainerRemoveOptions{Force: true})
	if err != nil {
		msg := strings.ToLower(err.Error())
		if !(strings.Contains(msg, "no such container") || strings.Contains(msg, "not found") || strings.Contains(msg, "does not exist")) {
		return err
		}
	}
	// 无论如何都要删数据库
	_, err = s.db.Exec("DELETE FROM containers WHERE id = ?", containerID)
	// 忽略数据库已无记录的情况
	// 清除用户的容器ID
	_, _ = s.db.Exec("UPDATE users SET container_id = '' WHERE container_id = ?", containerID)
	return nil
}

func (s *ContainerService) GetContainerByID(containerID string) (*models.Container, error) {
	container := &models.Container{}
	query := `
		SELECT id, user_id, name, status, image_name, cpu_limit, memory_limit, 
		       COALESCE(gpu_devices, ''), created_at, updated_at, last_seen
		FROM containers WHERE id = ?
	`
	
	err := s.db.QueryRow(query, containerID).Scan(
		&container.ID, &container.UserID, &container.Name, &container.Status,
		&container.ImageName, &container.CPULimit, &container.MemoryLimit,
		&container.GPUDevices, &container.CreatedAt, &container.UpdatedAt,
		&container.LastSeen,
	)
	
	if err != nil {
		return nil, err
	}
	
	return container, nil
}

func (s *ContainerService) GetContainerActualStatus(containerID string) (string, error) {
	// 从Docker获取容器的实际状态
	containerInfo, err := s.dockerClient.ContainerInspect(context.Background(), containerID)
	if err != nil {
		return "", fmt.Errorf("无法获取容器状态: %v", err)
	}

	// 根据Docker状态返回我们的状态格式
	if containerInfo.State.Running {
		return "running", nil
	} else {
		return "stopped", nil
	}
}

func (s *ContainerService) ListContainers() ([]interface{}, error) {
	query := `
		SELECT id, user_id, name, status, image_name, cpu_limit, memory_limit, 
		       COALESCE(gpu_devices, ''), created_at, updated_at, last_seen
		FROM containers ORDER BY created_at DESC
	`
	
	rows, err := s.db.Query(query)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	
	var containers []interface{}
	for rows.Next() {
		container := &models.Container{}
		err := rows.Scan(
			&container.ID, &container.UserID, &container.Name, &container.Status,
			&container.ImageName, &container.CPULimit, &container.MemoryLimit,
			&container.GPUDevices, &container.CreatedAt, &container.UpdatedAt,
			&container.LastSeen,
		)
		if err != nil {
			return nil, err
		}

		// 新增：实时检查Docker实际状态
		actualStatus := "missing"
		info, err := s.dockerClient.ContainerInspect(context.Background(), container.ID)
		if err == nil {
			if info.State.Running {
				actualStatus = "running"
			} else {
				actualStatus = "stopped"
			}
		}
		// 用map扩展返回
		containerMap := map[string]interface{}{
			"id": container.ID,
			"user_id": container.UserID,
			"name": container.Name,
			"status": container.Status,
			"image_name": container.ImageName,
			"cpu_limit": container.CPULimit,
			"memory_limit": container.MemoryLimit,
			"gpu_devices": container.GPUDevices,
			"created_at": container.CreatedAt,
			"updated_at": container.UpdatedAt,
			"last_seen": container.LastSeen,
			"actual_status": actualStatus,
		}
		containers = append(containers, containerMap)
	}
	if containers == nil {
		containers = []interface{}{}
	}
	return containers, nil
}

func (s *ContainerService) getExposedPorts(user *models.User) nat.PortSet {
	exposed := make(nat.PortSet)
	
	// 容器内需要暴露的端口
	containerPorts := []string{
		"22/tcp",   // SSH
		"8080/tcp", // VSCode Server
		"8888/tcp", // Jupyter Lab
	}
	
	// 添加备用应用端口 8003-8009
	for i := 3; i <= 9; i++ {
		containerPorts = append(containerPorts, fmt.Sprintf("80%02d/tcp", i))
	}
	
	for _, port := range containerPorts {
		portKey := nat.Port(port)
		exposed[portKey] = struct{}{}
	}
	
	return exposed
}

func (s *ContainerService) ResetContainerPassword(containerID, newPassword string) error {
	// 检查容器是否存在
	_, err := s.GetContainerByID(containerID)
	if err != nil {
		return fmt.Errorf("容器不存在: %v", err)
	}

	// 检查容器是否在运行
	containerInfo, err := s.dockerClient.ContainerInspect(context.Background(), containerID)
	if err != nil {
		return fmt.Errorf("无法获取容器状态: %v", err)
	}

	if !containerInfo.State.Running {
		return fmt.Errorf("容器未运行，无法重置密码")
	}

	// 获取容器内的用户名
	var username string
	for _, env := range containerInfo.Config.Env {
		if strings.HasPrefix(env, "DEV_USER=") {
			username = strings.TrimPrefix(env, "DEV_USER=")
			break
		}
	}
	if username == "" {
		username = "developer" // 默认用户名
	}

	// 执行密码重置命令
	// 1. 重置系统用户密码
	passwordInput := fmt.Sprintf("%s:%s", username, newPassword)
	execConfig := types.ExecConfig{
		Cmd:          []string{"chpasswd"},
		AttachStdin:  true,
		AttachStdout: true,
		AttachStderr: true,
	}

	execResp, err := s.dockerClient.ContainerExecCreate(context.Background(), containerID, execConfig)
	if err != nil {
		return fmt.Errorf("创建密码重置命令失败: %v", err)
	}

	execAttachResp, err := s.dockerClient.ContainerExecAttach(context.Background(), execResp.ID, types.ExecStartCheck{})
	if err != nil {
		return fmt.Errorf("执行密码重置命令失败: %v", err)
	}
	defer execAttachResp.Close()

	// 发送密码数据
	_, err = execAttachResp.Conn.Write([]byte(passwordInput + "\n"))
	if err != nil {
		return fmt.Errorf("写入密码数据失败: %v", err)
	}
	execAttachResp.Close()

	// 2. 更新Jupyter配置
	jupyterConfigScript := fmt.Sprintf(`
import os
from jupyter_server.auth import passwd

password_hash = passwd('%s')
config_content = '''c.ServerApp.ip = '0.0.0.0'
c.ServerApp.port = 8888
c.ServerApp.allow_root = True
c.ServerApp.open_browser = False
c.ServerApp.token = ''
c.ServerApp.password = '%s'
c.ServerApp.allow_origin = '*'
c.ServerApp.allow_remote_access = True
c.ServerApp.root_dir = '/home/%s'
c.ServerApp.disable_check_xsrf = True'''

os.makedirs('/home/%s/.jupyter', exist_ok=True)
with open('/home/%s/.jupyter/jupyter_lab_config.py', 'w') as f:
    f.write(config_content)
`, newPassword, "' + password_hash + '", username, username, username)

	execConfig2 := types.ExecConfig{
		Cmd:          []string{"python3", "-c", jupyterConfigScript},
		AttachStdout: true,
		AttachStderr: true,
	}

	execResp2, err := s.dockerClient.ContainerExecCreate(context.Background(), containerID, execConfig2)
	if err != nil {
		return fmt.Errorf("创建Jupyter配置更新命令失败: %v", err)
	}

	err = s.dockerClient.ContainerExecStart(context.Background(), execResp2.ID, types.ExecStartCheck{})
	if err != nil {
		return fmt.Errorf("执行Jupyter配置更新失败: %v", err)
	}

	// 3. 更新code-server配置
	codeServerConfig := fmt.Sprintf(`bind-addr: 0.0.0.0:8080
auth: password
password: %s
cert: false`, newPassword)

	execConfig3 := types.ExecConfig{
		Cmd: []string{"sh", "-c", fmt.Sprintf("mkdir -p /home/%s/.config/code-server && echo '%s' > /home/%s/.config/code-server/config.yaml", username, codeServerConfig, username)},
		AttachStdout: true,
		AttachStderr: true,
	}

	execResp3, err := s.dockerClient.ContainerExecCreate(context.Background(), containerID, execConfig3)
	if err != nil {
		return fmt.Errorf("创建VSCode配置更新命令失败: %v", err)
	}

	err = s.dockerClient.ContainerExecStart(context.Background(), execResp3.ID, types.ExecStartCheck{})
	if err != nil {
		return fmt.Errorf("执行VSCode配置更新失败: %v", err)
	}

	// 4. 重启服务（可选，杀死现有进程让它们重启）
	killServicesScript := `
pkill -f "jupyter lab" || true
pkill -f "code-server" || true
sleep 2
# 重启服务
su - ` + username + ` -c "nohup jupyter lab --config=/home/` + username + `/.jupyter/jupyter_lab_config.py > /tmp/jupyter.log 2>&1 &"
su - ` + username + ` -c "nohup code-server > /tmp/code-server.log 2>&1 &"
`

	execConfig4 := types.ExecConfig{
		Cmd:          []string{"sh", "-c", killServicesScript},
		AttachStdout: true,
		AttachStderr: true,
	}

	execResp4, err := s.dockerClient.ContainerExecCreate(context.Background(), containerID, execConfig4)
	if err != nil {
		return fmt.Errorf("创建服务重启命令失败: %v", err)
	}

	err = s.dockerClient.ContainerExecStart(context.Background(), execResp4.ID, types.ExecStartCheck{})
	if err != nil {
		return fmt.Errorf("执行服务重启失败: %v", err)
	}

	return nil
}

func (s *ContainerService) getPortBindings(user *models.User) nat.PortMap {
	ports := user.GetPorts()
	bindings := make(nat.PortMap)
	
	// SSH (端口22 -> base_port+0)
	sshPort := nat.Port("22/tcp")
	bindings[sshPort] = []nat.PortBinding{
		{HostPort: strconv.Itoa(ports["ssh"])},
	}
	
	// VSCode Server (端口8080 -> base_port+1)
	vscodePort := nat.Port("8080/tcp")
	bindings[vscodePort] = []nat.PortBinding{
		{HostPort: strconv.Itoa(ports["vscode"])},
	}
	
	// Jupyter Lab (端口8888 -> base_port+2)
	jupyterPort := nat.Port("8888/tcp")
	bindings[jupyterPort] = []nat.PortBinding{
		{HostPort: strconv.Itoa(ports["jupyter"])},
	}
	
	// 备用应用端口映射 (容器内端口8003-8009 -> base_port+3到base_port+9)
	for i := 3; i <= 9; i++ {
		containerPort := nat.Port(fmt.Sprintf("80%02d/tcp", i))
		appKey := fmt.Sprintf("app%d", i)
		bindings[containerPort] = []nat.PortBinding{
			{HostPort: strconv.Itoa(ports[appKey])},
		}
	}
	
	return bindings
}