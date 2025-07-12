package models

import "time"

type Container struct {
	ID          string    `json:"id" db:"id"`
	UserID      int       `json:"user_id" db:"user_id"`
	Name        string    `json:"name" db:"name"`
	Status      string    `json:"status" db:"status"` // running, stopped, error
	ImageName   string    `json:"image_name" db:"image_name"`
	CPULimit    string    `json:"cpu_limit" db:"cpu_limit"`
	MemoryLimit string    `json:"memory_limit" db:"memory_limit"`
	GPUDevices  string    `json:"gpu_devices" db:"gpu_devices"` // GPU设备ID，逗号分隔
	CreatedAt   time.Time `json:"created_at" db:"created_at"`
	UpdatedAt   time.Time `json:"updated_at" db:"updated_at"`
	LastSeen    time.Time `json:"last_seen" db:"last_seen"`
}

type ContainerStats struct {
	ContainerID string  `json:"container_id"`
	CPUUsage    float64 `json:"cpu_usage"`
	MemoryUsage int64   `json:"memory_usage"`
	GPUUsage    float64 `json:"gpu_usage"`
	Timestamp   time.Time `json:"timestamp"`
}