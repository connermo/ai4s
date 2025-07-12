package handlers

import (
	"encoding/json"
	"net/http"
	"strconv"

	"../services"
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

	container, err := h.containerService.CreateContainer(user, req.GPUDevices)
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