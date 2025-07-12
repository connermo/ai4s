package services

import (
	"context"
	"database/sql"
	"fmt"
	"os"
	"strconv"
	"time"

	"gpu-dev-platform/database"
	"gpu-dev-platform/models"
	"github.com/docker/docker/api/types"
	"github.com/docker/docker/api/types/container"
	"github.com/docker/docker/client"
	"github.com/docker/go-connections/nat"
)

type ContainerService struct {
	db           *sql.DB
	dockerClient *client.Client
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
	containerName := fmt.Sprintf("dev-%s", user.Username)
	
	// 创建容器配置
	config := &container.Config{
		Image: "gpu-dev-env:latest",
		// 不设置User，让容器以root启动确保SSH服务可以运行
		Env: []string{
			fmt.Sprintf("DEV_USER=%s", user.Username),
			fmt.Sprintf("DEV_UID=%d", user.ID+1000),
			fmt.Sprintf("DEV_GID=%d", user.ID+1000),
			fmt.Sprintf("DEV_PASSWORD=%s123", user.Username), // 设置默认密码为用户名+123
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
		workspaceDataPath = "/app/workspace"
	}
	
	containerHomePath := os.Getenv("CONTAINER_HOME_PATH")
	if containerHomePath == "" {
		containerHomePath = "/home"
	}
	
	containerSharedPath := os.Getenv("CONTAINER_SHARED_PATH")
	if containerSharedPath == "" {
		containerSharedPath = "/shared"
	}
	
	containerWorkspacePath := os.Getenv("CONTAINER_WORKSPACE_PATH")
	if containerWorkspacePath == "" {
		containerWorkspacePath = "/workspace"
	}

	hostConfig := &container.HostConfig{
		PortBindings: s.getPortBindings(user),
		Binds: []string{
			fmt.Sprintf("%s/%s:%s/%s", usersDataPath, user.Username, containerHomePath, user.Username),
			fmt.Sprintf("%s:%s:ro", sharedDataPath, containerSharedPath),
			fmt.Sprintf("%s:%s", workspaceDataPath, containerWorkspacePath),
		},
		// 不限制资源，让容器使用宿主机全部资源
		Resources: container.Resources{},
		RestartPolicy: container.RestartPolicy{
			Name: "unless-stopped",
		},
	}

	// 如果有GPU设备，添加GPU配置
	if gpuDevices != "" {
		hostConfig.DeviceRequests = []container.DeviceRequest{
			{
				Driver:       "nvidia",
				Count:        -1, // 所有GPU
				DeviceIDs:    []string{gpuDevices},
				Capabilities: [][]string{{"gpu"}},
			},
		}
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
		ImageName:   "gpu-dev-env:latest",
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
		return err
	}

	// 从数据库删除
	_, err = s.db.Exec("DELETE FROM containers WHERE id = ?", containerID)
	if err != nil {
		return err
	}

	// 清除用户的容器ID
	_, err = s.db.Exec("UPDATE users SET container_id = '' WHERE container_id = ?", 
		containerID)
	return err
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

func (s *ContainerService) ListContainers() ([]*models.Container, error) {
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
	
	var containers []*models.Container
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
		containers = append(containers, container)
	}
	
	// 确保返回空数组而不是nil
	if containers == nil {
		containers = []*models.Container{}
	}
	
	return containers, nil
}

func (s *ContainerService) getExposedPorts(user *models.User) nat.PortSet {
	exposed := make(nat.PortSet)
	
	// 容器内需要暴露的端口
	containerPorts := []string{
		"22/tcp",    // SSH
		"8080/tcp",  // VSCode Server
		"8888/tcp",  // Jupyter Lab
		"6006/tcp",  // TensorBoard
	}
	
	// 添加备用应用端口 8004-8009
	for i := 4; i <= 9; i++ {
		containerPorts = append(containerPorts, fmt.Sprintf("80%02d/tcp", i))
	}
	
	for _, port := range containerPorts {
		portKey := nat.Port(port)
		exposed[portKey] = struct{}{}
	}
	
	return exposed
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
	
	// TensorBoard (端口6006 -> base_port+3)
	tensorboardPort := nat.Port("6006/tcp")
	bindings[tensorboardPort] = []nat.PortBinding{
		{HostPort: strconv.Itoa(ports["tensorboard"])},
	}
	
	// 备用应用端口映射 (容器内端口8004-8009 -> base_port+4到base_port+9)
	for i := 4; i <= 9; i++ {
		containerPort := nat.Port(fmt.Sprintf("80%02d/tcp", i))
		appKey := fmt.Sprintf("app%d", i-3)
		bindings[containerPort] = []nat.PortBinding{
			{HostPort: strconv.Itoa(ports[appKey])},
		}
	}
	
	return bindings
}