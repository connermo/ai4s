package handlers

import (
	"database/sql"
	"encoding/json"
	"net/http"
	"strconv"

	"gpu-dev-platform/database"
	"gpu-dev-platform/services"
)

type UserSelfHandler struct {
	db               *sql.DB
	containerService *services.ContainerService
}

type UserResetPasswordRequest struct {
	ContainerID string `json:"container_id"`
	Password    string `json:"password"`
}

func NewUserSelfHandler() (*UserSelfHandler, error) {
	containerService, err := services.NewContainerService()
	if err != nil {
		return nil, err
	}

	return &UserSelfHandler{
		db:               database.DB,
		containerService: containerService,
	}, nil
}

// 用户重置自己容器的密码
func (h *UserSelfHandler) ResetContainerPassword(w http.ResponseWriter, r *http.Request) {
	// 从请求头获取用户ID
	userIDStr := r.Header.Get("X-User-ID")
	if userIDStr == "" {
		http.Error(w, "未找到用户信息", http.StatusUnauthorized)
		return
	}

	userID, err := strconv.Atoi(userIDStr)
	if err != nil {
		http.Error(w, "无效的用户ID", http.StatusBadRequest)
		return
	}

	var req UserResetPasswordRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "无效的请求格式", http.StatusBadRequest)
		return
	}

	if req.ContainerID == "" || req.Password == "" {
		http.Error(w, "容器ID和密码不能为空", http.StatusBadRequest)
		return
	}

	if len(req.Password) < 6 {
		http.Error(w, "密码长度至少6位", http.StatusBadRequest)
		return
	}

	// 验证容器是否属于当前用户
	var containerUserID int
	query := "SELECT user_id FROM containers WHERE id = ?"
	err = h.db.QueryRow(query, req.ContainerID).Scan(&containerUserID)
	if err != nil {
		if err == sql.ErrNoRows {
			http.Error(w, "容器不存在", http.StatusNotFound)
		} else {
			http.Error(w, "数据库查询失败", http.StatusInternalServerError)
		}
		return
	}

	if containerUserID != userID {
		http.Error(w, "无权操作此容器", http.StatusForbidden)
		return
	}

	// 重置容器密码
	if err := h.containerService.ResetContainerPassword(req.ContainerID, req.Password); err != nil {
		http.Error(w, "重置密码失败: "+err.Error(), http.StatusInternalServerError)
		return
	}

	w.WriteHeader(http.StatusOK)
	w.Write([]byte("密码重置成功"))
}

// 获取用户自己的信息
func (h *UserSelfHandler) GetSelfInfo(w http.ResponseWriter, r *http.Request) {
	userIDStr := r.Header.Get("X-User-ID")
	if userIDStr == "" {
		http.Error(w, "未找到用户信息", http.StatusUnauthorized)
		return
	}

	userID, err := strconv.Atoi(userIDStr)
	if err != nil {
		http.Error(w, "无效的用户ID", http.StatusBadRequest)
		return
	}

	// 获取用户信息
	query := `SELECT id, username, email, is_active, is_admin, created_at, updated_at, 
	          COALESCE(container_id, '') as container_id
	          FROM users WHERE id = ?`
	
	var id int
	var username, email string
	var isActive, isAdmin bool
	var createdAt, updatedAt string
	var containerID string
	
	err = h.db.QueryRow(query, userID).Scan(
		&id, &username, &email,
		&isActive, &isAdmin, &createdAt, &updatedAt,
		&containerID,
	)

	if err != nil {
		if err == sql.ErrNoRows {
			http.Error(w, "用户不存在", http.StatusNotFound)
		} else {
			http.Error(w, "数据库查询失败", http.StatusInternalServerError)
		}
		return
	}

	// 构造返回的用户数据
	user := map[string]interface{}{
		"id":           id,
		"username":     username,
		"email":        email,
		"is_active":    isActive,
		"is_admin":     isAdmin,
		"created_at":   createdAt,
		"updated_at":   updatedAt,
		"container_id": containerID,
	}

	// 计算端口范围
	portStart := 9000 + (id-1)*10
	user["port_start"] = portStart

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(user)
}

// 获取用户容器信息
func (h *UserSelfHandler) GetSelfContainer(w http.ResponseWriter, r *http.Request) {
	userIDStr := r.Header.Get("X-User-ID")
	if userIDStr == "" {
		http.Error(w, "未找到用户信息", http.StatusUnauthorized)
		return
	}

	userID, err := strconv.Atoi(userIDStr)
	if err != nil {
		http.Error(w, "无效的用户ID", http.StatusBadRequest)
		return
	}

	// 获取用户的容器ID
	var containerID string
	query := "SELECT COALESCE(container_id, '') FROM users WHERE id = ?"
	err = h.db.QueryRow(query, userID).Scan(&containerID)
	if err != nil {
		http.Error(w, "查询用户信息失败", http.StatusInternalServerError)
		return
	}

	if containerID == "" {
		http.Error(w, "用户暂未分配容器", http.StatusNotFound)
		return
	}

	// 获取容器详细信息
	container, err := h.containerService.GetContainerByID(containerID)
	if err != nil {
		http.Error(w, "获取容器信息失败", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(container)
}