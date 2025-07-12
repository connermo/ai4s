package services

import (
	"context"
	"database/sql"
	"fmt"
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
		User:  fmt.Sprintf("%d:%d", user.ID+1000, user.ID+1000), // 映射到容器内用户
		Env: []string{
			fmt.Sprintf("DEV_USER=%s", user.Username),
			fmt.Sprintf("DEV_UID=%d", user.ID+1000),
			fmt.Sprintf("DEV_GID=%d", user.ID+1000),
		},
		ExposedPorts: s.getExposedPorts(user),
	}

	hostConfig := &container.HostConfig{
		PortBindings: s.getPortBindings(user),
		Binds: []string{
			fmt.Sprintf("./users/%s:/home/%s", user.Username, user.Username),
			"./shared:/shared:ro",
			"./workspace:/workspace",
		},
		Resources: container.Resources{
			Memory:   4 * 1024 * 1024 * 1024, // 4GB
			CPUCount: 2,
		},
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
		CPULimit:    "2",
		MemoryLimit: "4g",
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
	ports := user.GetPorts()
	exposed := make(nat.PortSet)
	
	for _, port := range ports {
		portKey := nat.Port(fmt.Sprintf("%d/tcp", port))
		exposed[portKey] = struct{}{}
	}
	
	return exposed
}

func (s *ContainerService) getPortBindings(user *models.User) nat.PortMap {
	ports := user.GetPorts()
	bindings := make(nat.PortMap)
	
	// SSH
	sshPort := nat.Port(strconv.Itoa(ports["ssh"]) + "/tcp")
	bindings[sshPort] = []nat.PortBinding{
		{HostPort: strconv.Itoa(ports["ssh"])},
	}
	
	// VSCode Server
	vscodePort := nat.Port("8080/tcp")
	bindings[vscodePort] = []nat.PortBinding{
		{HostPort: strconv.Itoa(ports["vscode"])},
	}
	
	// Jupyter Lab
	jupyterPort := nat.Port("8888/tcp")
	bindings[jupyterPort] = []nat.PortBinding{
		{HostPort: strconv.Itoa(ports["jupyter"])},
	}
	
	// TensorBoard
	tensorboardPort := nat.Port("6006/tcp")
	bindings[tensorboardPort] = []nat.PortBinding{
		{HostPort: strconv.Itoa(ports["tensorboard"])},
	}
	
	return bindings
}