package handlers

import (
	"encoding/json"
	"net/http"
	"strconv"

	"gpu-dev-platform/services"
	"github.com/gorilla/mux"
)

type ContainerHandler struct {
	containerService *services.ContainerService
	userService      *services.UserService
}

func NewContainerHandler() (*ContainerHandler, error) {
	containerService, err := services.NewContainerService()
	if err != nil {
		return nil, err
	}

	return &ContainerHandler{
		containerService: containerService,
		userService:      services.NewUserService(),
	}, nil
}

type CreateContainerRequest struct {
	UserID     int    `json:"user_id"`
	GPUDevices string `json:"gpu_devices"`
	Password   string `json:"password,omitempty"` // 服务登录密码
}

func (h *ContainerHandler) CreateContainer(w http.ResponseWriter, r *http.Request) {
	var req CreateContainerRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}

	user, err := h.userService.GetUserByID(req.UserID)
	if err != nil {
		http.Error(w, "User not found", http.StatusNotFound)
		return
	}

	// 验证密码是否提供
	if req.Password == "" {
		http.Error(w, "服务登录密码不能为空", http.StatusBadRequest)
		return
	}
	
	password := req.Password
	
	container, err := h.containerService.CreateContainerWithPassword(user, req.GPUDevices, password)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(container)
}

func (h *ContainerHandler) GetContainer(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	containerID := vars["id"]

	container, err := h.containerService.GetContainerByID(containerID)
	if err != nil {
		http.Error(w, "Container not found", http.StatusNotFound)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(container)
}

func (h *ContainerHandler) GetContainerStatus(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	containerID := vars["id"]

	status, err := h.containerService.GetContainerActualStatus(containerID)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	response := map[string]string{
		"status": status,
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

func (h *ContainerHandler) ListContainers(w http.ResponseWriter, r *http.Request) {
	containers, err := h.containerService.ListContainers()
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(containers)
}

func (h *ContainerHandler) StartContainer(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	containerID := vars["id"]

	if err := h.containerService.StartContainer(containerID); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.WriteHeader(http.StatusOK)
}

func (h *ContainerHandler) StopContainer(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	containerID := vars["id"]

	if err := h.containerService.StopContainer(containerID); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.WriteHeader(http.StatusOK)
}

func (h *ContainerHandler) RemoveContainer(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	containerID := vars["id"]

	if err := h.containerService.RemoveContainer(containerID); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.WriteHeader(http.StatusOK)
}

func (h *ContainerHandler) GetUserContainer(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	userID, err := strconv.Atoi(vars["userId"])
	if err != nil {
		http.Error(w, "Invalid user ID", http.StatusBadRequest)
		return
	}

	user, err := h.userService.GetUserByID(userID)
	if err != nil {
		http.Error(w, "User not found", http.StatusNotFound)
		return
	}

	if user.ContainerID == "" {
		http.Error(w, "User has no container", http.StatusNotFound)
		return
	}

	container, err := h.containerService.GetContainerByID(user.ContainerID)
	if err != nil {
		http.Error(w, "Container not found", http.StatusNotFound)
		return
	}

	// 添加端口信息
	response := map[string]interface{}{
		"container": container,
		"ports":     user.GetPorts(),
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

type ResetPasswordRequest struct {
	Password string `json:"password"`
}

func (h *ContainerHandler) ResetContainerPassword(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	containerID := vars["id"]

	var req ResetPasswordRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}

	// 验证新密码
	if req.Password == "" {
		http.Error(w, "新密码不能为空", http.StatusBadRequest)
		return
	}

	if len(req.Password) < 6 {
		http.Error(w, "密码长度至少6位", http.StatusBadRequest)
		return
	}

	// 重置容器服务密码
	if err := h.containerService.ResetContainerPassword(containerID, req.Password); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.WriteHeader(http.StatusOK)
	w.Write([]byte("密码重置成功"))
}