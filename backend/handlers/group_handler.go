package handlers

import (
	"encoding/json"
	"net/http"
	"strconv"

	"gpu-dev-platform/models"
	"gpu-dev-platform/services"
	"github.com/gorilla/mux"
)

type GroupHandler struct {
	groupService *services.GroupService
	userService  *services.UserService
}

func NewGroupHandler() *GroupHandler {
	return &GroupHandler{
		groupService: services.NewGroupService(),
		userService:  services.NewUserService(),
	}
}

// ListGroups 获取组列表
func (h *GroupHandler) ListGroups(w http.ResponseWriter, r *http.Request) {
	userID := r.Context().Value("user_id").(int)
	isAdmin := r.Context().Value("is_admin").(bool)

	groups, err := h.groupService.GetGroups(userID, isAdmin)
	if err != nil {
		http.Error(w, "Failed to get groups: "+err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"success": true,
		"data":    groups,
	})
}

// CreateGroup 创建组
func (h *GroupHandler) CreateGroup(w http.ResponseWriter, r *http.Request) {
	userID := r.Context().Value("user_id").(int)

	var req models.GroupCreateRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}

	// 验证请求数据
	if req.Name == "" {
		http.Error(w, "Group name is required", http.StatusBadRequest)
		return
	}
	if len(req.Name) < 2 || len(req.Name) > 50 {
		http.Error(w, "Group name must be between 2 and 50 characters", http.StatusBadRequest)
		return
	}

	group, err := h.groupService.CreateGroup(&req, userID)
	if err != nil {
		http.Error(w, "Failed to create group: "+err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(map[string]interface{}{
		"success": true,
		"message": "Group created successfully",
		"data":    group,
	})
}

// GetGroup 获取组详情
func (h *GroupHandler) GetGroup(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	groupID, err := strconv.Atoi(vars["id"])
	if err != nil {
		http.Error(w, "Invalid group ID", http.StatusBadRequest)
		return
	}

	userID := r.Context().Value("user_id").(int)
	isAdmin := r.Context().Value("is_admin").(bool)

	// 检查访问权限
	if !isAdmin {
		isMember, err := h.groupService.IsGroupMember(groupID, userID)
		if err != nil {
			http.Error(w, "Failed to check membership", http.StatusInternalServerError)
			return
		}
		if !isMember {
			http.Error(w, "Permission denied", http.StatusForbidden)
			return
		}
	}

	group, err := h.groupService.GetGroupByID(groupID)
	if err != nil {
		http.Error(w, "Group not found", http.StatusNotFound)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"success": true,
		"data":    group,
	})
}

// UpdateGroup 更新组信息
func (h *GroupHandler) UpdateGroup(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	groupID, err := strconv.Atoi(vars["id"])
	if err != nil {
		http.Error(w, "Invalid group ID", http.StatusBadRequest)
		return
	}

	userID := r.Context().Value("user_id").(int)
	isAdmin := r.Context().Value("is_admin").(bool)

	var req models.GroupUpdateRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}

	// 验证请求数据
	if req.Name == "" {
		http.Error(w, "Group name is required", http.StatusBadRequest)
		return
	}
	if len(req.Name) < 2 || len(req.Name) > 50 {
		http.Error(w, "Group name must be between 2 and 50 characters", http.StatusBadRequest)
		return
	}

	err = h.groupService.UpdateGroup(groupID, &req, userID, isAdmin)
	if err != nil {
		if err.Error() == "permission denied" {
			http.Error(w, "Permission denied", http.StatusForbidden)
			return
		}
		http.Error(w, "Failed to update group: "+err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"success": true,
		"message": "Group updated successfully",
	})
}

// DeleteGroup 删除组
func (h *GroupHandler) DeleteGroup(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	groupID, err := strconv.Atoi(vars["id"])
	if err != nil {
		http.Error(w, "Invalid group ID", http.StatusBadRequest)
		return
	}

	userID := r.Context().Value("user_id").(int)
	isAdmin := r.Context().Value("is_admin").(bool)

	err = h.groupService.DeleteGroup(groupID, userID, isAdmin)
	if err != nil {
		if err.Error() == "permission denied" {
			http.Error(w, "Permission denied", http.StatusForbidden)
			return
		}
		http.Error(w, "Failed to delete group: "+err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"success": true,
		"message": "Group deleted successfully",
	})
}

// GetGroupMembers 获取组成员列表
func (h *GroupHandler) GetGroupMembers(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	groupID, err := strconv.Atoi(vars["id"])
	if err != nil {
		http.Error(w, "Invalid group ID", http.StatusBadRequest)
		return
	}

	userID := r.Context().Value("user_id").(int)
	isAdmin := r.Context().Value("is_admin").(bool)

	members, err := h.groupService.GetGroupMembers(groupID, userID, isAdmin)
	if err != nil {
		if err.Error() == "permission denied" {
			http.Error(w, "Permission denied", http.StatusForbidden)
			return
		}
		http.Error(w, "Failed to get group members: "+err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"success": true,
		"data":    members,
	})
}

// AddGroupMember 添加组成员
func (h *GroupHandler) AddGroupMember(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	groupID, err := strconv.Atoi(vars["id"])
	if err != nil {
		http.Error(w, "Invalid group ID", http.StatusBadRequest)
		return
	}

	userID := r.Context().Value("user_id").(int)
	isAdmin := r.Context().Value("is_admin").(bool)

	var req models.AddMemberRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}

	// 验证请求数据
	if req.UserID <= 0 {
		http.Error(w, "Invalid user ID", http.StatusBadRequest)
		return
	}
	if req.Role != "member" && req.Role != "admin" {
		http.Error(w, "Role must be 'member' or 'admin'", http.StatusBadRequest)
		return
	}

	err = h.groupService.AddGroupMember(groupID, &req, userID, isAdmin)
	if err != nil {
		if err.Error() == "permission denied" {
			http.Error(w, "Permission denied", http.StatusForbidden)
			return
		}
		http.Error(w, "Failed to add member: "+err.Error(), http.StatusBadRequest)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(map[string]interface{}{
		"success": true,
		"message": "Member added successfully",
	})
}

// RemoveGroupMember 移除组成员
func (h *GroupHandler) RemoveGroupMember(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	groupID, err := strconv.Atoi(vars["id"])
	if err != nil {
		http.Error(w, "Invalid group ID", http.StatusBadRequest)
		return
	}

	memberUserID, err := strconv.Atoi(vars["user_id"])
	if err != nil {
		http.Error(w, "Invalid user ID", http.StatusBadRequest)
		return
	}

	userID := r.Context().Value("user_id").(int)
	isAdmin := r.Context().Value("is_admin").(bool)

	err = h.groupService.RemoveGroupMember(groupID, memberUserID, userID, isAdmin)
	if err != nil {
		if err.Error() == "permission denied" {
			http.Error(w, "Permission denied", http.StatusForbidden)
			return
		}
		http.Error(w, "Failed to remove member: "+err.Error(), http.StatusBadRequest)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"success": true,
		"message": "Member removed successfully",
	})
}

// UpdateMemberRole 更新成员角色
func (h *GroupHandler) UpdateMemberRole(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	groupID, err := strconv.Atoi(vars["id"])
	if err != nil {
		http.Error(w, "Invalid group ID", http.StatusBadRequest)
		return
	}

	memberUserID, err := strconv.Atoi(vars["user_id"])
	if err != nil {
		http.Error(w, "Invalid user ID", http.StatusBadRequest)
		return
	}

	userID := r.Context().Value("user_id").(int)
	isAdmin := r.Context().Value("is_admin").(bool)

	var req models.UpdateMemberRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}

	// 验证请求数据
	if req.Role != "member" && req.Role != "admin" {
		http.Error(w, "Role must be 'member' or 'admin'", http.StatusBadRequest)
		return
	}

	err = h.groupService.UpdateMemberRole(groupID, memberUserID, userID, &req, isAdmin)
	if err != nil {
		if err.Error() == "permission denied" {
			http.Error(w, "Permission denied", http.StatusForbidden)
			return
		}
		http.Error(w, "Failed to update member role: "+err.Error(), http.StatusBadRequest)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"success": true,
		"message": "Member role updated successfully",
	})
}

// GetUserGroups 获取用户所属的组
func (h *GroupHandler) GetUserGroups(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	targetUserID, err := strconv.Atoi(vars["user_id"])
	if err != nil {
		http.Error(w, "Invalid user ID", http.StatusBadRequest)
		return
	}

	userID := r.Context().Value("user_id").(int)
	isAdmin := r.Context().Value("is_admin").(bool)

	// 检查访问权限（只能查看自己的组或管理员查看所有）
	if !isAdmin && userID != targetUserID {
		http.Error(w, "Permission denied", http.StatusForbidden)
		return
	}

	userGroups, err := h.groupService.GetUserGroups(targetUserID)
	if err != nil {
		http.Error(w, "Failed to get user groups: "+err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"success": true,
		"data":    userGroups,
	})
}

// GetAvailableUsers 获取可添加到组的用户列表
func (h *GroupHandler) GetAvailableUsers(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	groupID, err := strconv.Atoi(vars["id"])
	if err != nil {
		http.Error(w, "Invalid group ID", http.StatusBadRequest)
		return
	}

	userID := r.Context().Value("user_id").(int)
	isAdmin := r.Context().Value("is_admin").(bool)

	// 检查管理权限
	canManage, err := h.groupService.CanManageGroup(groupID, userID, isAdmin)
	if err != nil {
		http.Error(w, "Failed to check permissions", http.StatusInternalServerError)
		return
	}
	if !canManage {
		http.Error(w, "Permission denied", http.StatusForbidden)
		return
	}

	// 获取不在该组的用户列表
	users, err := h.userService.GetUsersNotInGroup(groupID)
	if err != nil {
		http.Error(w, "Failed to get available users: "+err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"success": true,
		"data":    users,
	})
}