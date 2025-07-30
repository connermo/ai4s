package models

import (
	"time"
)

// Group 组模型
type Group struct {
	ID          int       `json:"id" db:"id"`
	Name        string    `json:"name" db:"name"`
	Description string    `json:"description" db:"description"`
	GID         int       `json:"gid" db:"gid"`                 // Linux 组 GID
	CreatedBy   int       `json:"created_by" db:"created_by"`   // 创建者用户ID
	CreatedAt   time.Time `json:"created_at" db:"created_at"`
	UpdatedAt   time.Time `json:"updated_at" db:"updated_at"`
	
	// 扩展字段，不存储在数据库中
	CreatedByUsername string      `json:"created_by_username,omitempty" db:"-"`
	MemberCount       int         `json:"member_count,omitempty" db:"-"`
	Members           []UserGroup `json:"members,omitempty" db:"-"`
}

// UserGroup 用户组关系模型
type UserGroup struct {
	ID       int       `json:"id" db:"id"`
	UserID   int       `json:"user_id" db:"user_id"`
	GroupID  int       `json:"group_id" db:"group_id"`
	Role     string    `json:"role" db:"role"`       // member, admin
	JoinedAt time.Time `json:"joined_at" db:"joined_at"`
	
	// 扩展字段，用于关联查询
	Username  string `json:"username,omitempty" db:"username"`
	UserEmail string `json:"user_email,omitempty" db:"email"`
	GroupName string `json:"group_name,omitempty" db:"group_name"`
}

// GIDAllocation GID分配跟踪模型
type GIDAllocation struct {
	GID         int       `json:"gid" db:"gid"`
	AllocatedAt time.Time `json:"allocated_at" db:"allocated_at"`
	Purpose     string    `json:"purpose" db:"purpose"`
}

// SystemConfig 系统配置模型
type SystemConfig struct {
	KeyName     string `json:"key_name" db:"key_name"`
	ValueInt    *int   `json:"value_int" db:"value_int"`
	ValueStr    string `json:"value_str" db:"value_str"`
	Description string `json:"description" db:"description"`
}

// GroupCreateRequest 创建组请求
type GroupCreateRequest struct {
	Name        string `json:"name" validate:"required,min=2,max=50"`
	Description string `json:"description" validate:"max=500"`
}

// GroupUpdateRequest 更新组请求
type GroupUpdateRequest struct {
	Name        string `json:"name" validate:"required,min=2,max=50"`
	Description string `json:"description" validate:"max=500"`
}

// AddMemberRequest 添加成员请求
type AddMemberRequest struct {
	UserID int    `json:"user_id" validate:"required"`
	Role   string `json:"role" validate:"required,oneof=member admin"`
}

// UpdateMemberRequest 更新成员角色请求
type UpdateMemberRequest struct {
	Role string `json:"role" validate:"required,oneof=member admin"`
}

// GroupWithPermissions 包含权限信息的组
type GroupWithPermissions struct {
	Group
	UserRole       string `json:"user_role,omitempty"`        // 当前用户在组中的角色
	CanManage      bool   `json:"can_manage"`                 // 是否可以管理此组
	CanAddMembers  bool   `json:"can_add_members"`            // 是否可以添加成员
	CanRemoveMembers bool `json:"can_remove_members"`         // 是否可以移除成员
}