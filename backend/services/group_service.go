package services

import (
	"database/sql"
	"fmt"
	"os"
	"path/filepath"

	"gpu-dev-platform/database"
	"gpu-dev-platform/models"
)

type GroupService struct {
	db *sql.DB
}

func NewGroupService() *GroupService {
	return &GroupService{
		db: database.DB,
	}
}

// GetNextAvailableGID 获取下一个可用的 GID
func (s *GroupService) GetNextAvailableGID() (int, error) {
	// 获取配置的 GID 范围
	var minGID, maxGID int
	err := s.db.QueryRow("SELECT value_int FROM system_config WHERE key_name = 'min_group_gid'").Scan(&minGID)
	if err != nil {
		minGID = 2000 // 默认值
	}
	
	err = s.db.QueryRow("SELECT value_int FROM system_config WHERE key_name = 'max_group_gid'").Scan(&maxGID)
	if err != nil {
		maxGID = 65535 // 默认值
	}

	// 找到第一个未分配的 GID
	for gid := minGID; gid <= maxGID; gid++ {
		var count int
		err := s.db.QueryRow("SELECT COUNT(*) FROM gid_allocation WHERE gid = ?", gid).Scan(&count)
		if err != nil {
			return 0, err
		}
		if count == 0 {
			return gid, nil
		}
	}
	
	return 0, fmt.Errorf("no available GID in range %d-%d", minGID, maxGID)
}

// AllocateGID 分配 GID
func (s *GroupService) AllocateGID(gid int) error {
	_, err := s.db.Exec("INSERT INTO gid_allocation (gid) VALUES (?)", gid)
	return err
}

// DeallocateGID 释放 GID
func (s *GroupService) DeallocateGID(gid int) error {
	_, err := s.db.Exec("DELETE FROM gid_allocation WHERE gid = ?", gid)
	return err
}

// CreateGroup 创建组
func (s *GroupService) CreateGroup(req *models.GroupCreateRequest, createdBy int) (*models.Group, error) {
	// 检查组名是否已存在
	var count int
	err := s.db.QueryRow("SELECT COUNT(*) FROM grps WHERE name = ?", req.Name).Scan(&count)
	if err != nil {
		return nil, err
	}
	if count > 0 {
		return nil, fmt.Errorf("group name '%s' already exists", req.Name)
	}

	// 获取可用的 GID
	gid, err := s.GetNextAvailableGID()
	if err != nil {
		return nil, fmt.Errorf("failed to allocate GID: %v", err)
	}

	// 开启事务
	tx, err := s.db.Begin()
	if err != nil {
		return nil, err
	}
	defer tx.Rollback()

	// 分配 GID
	if err := s.AllocateGID(gid); err != nil {
		return nil, fmt.Errorf("failed to allocate GID: %v", err)
	}

	// 创建组
	result, err := tx.Exec(`
		INSERT INTO grps (name, description, gid, created_by) 
		VALUES (?, ?, ?, ?)`,
		req.Name, req.Description, gid, createdBy)
	if err != nil {
		s.DeallocateGID(gid) // 回滚 GID 分配
		return nil, err
	}

	groupID, err := result.LastInsertId()
	if err != nil {
		s.DeallocateGID(gid)
		return nil, err
	}

	// 创建组目录
	if err := s.CreateGroupDirectory(req.Name, gid); err != nil {
		s.DeallocateGID(gid)
		return nil, fmt.Errorf("failed to create group directory: %v", err)
	}

	// 自动将创建者添加为组管理员
	_, err = tx.Exec(`
		INSERT INTO user_groups (user_id, group_id, role) 
		VALUES (?, ?, 'admin')`,
		createdBy, groupID)
	if err != nil {
		s.DeallocateGID(gid)
		return nil, err
	}

	if err := tx.Commit(); err != nil {
		s.DeallocateGID(gid)
		return nil, err
	}

	// 返回创建的组信息
	return s.GetGroupByID(int(groupID))
}

// CreateGroupDirectory 创建组目录结构
func (s *GroupService) CreateGroupDirectory(groupName string, gid int) error {
	groupsPath := os.Getenv("GROUPS_DATA_PATH")
	if groupsPath == "" {
		groupsPath = "./data/groups"
	}

	groupDir := filepath.Join(groupsPath, groupName)
	
	// 创建主目录和子目录
	dirs := []string{
		groupDir,
		filepath.Join(groupDir, "shared"),
		filepath.Join(groupDir, "projects"),
		filepath.Join(groupDir, "resources"),
	}

	for _, dir := range dirs {
		if err := os.MkdirAll(dir, 0775); err != nil {
			return fmt.Errorf("failed to create directory %s: %v", dir, err)
		}

		// 设置目录所有者和权限
		if err := os.Chown(dir, 0, gid); err != nil {
			// 如果不能设置所有者，至少尝试设置权限
			os.Chmod(dir, 0775)
		}
	}

	return nil
}

// GetGroups 获取组列表
func (s *GroupService) GetGroups(userID int, isAdmin bool) ([]models.GroupWithPermissions, error) {
	var query string
	var args []interface{}

	if isAdmin {
		// 管理员可以看到所有组
		query = `
			SELECT g.id, g.name, g.description, g.gid, g.created_by, g.created_at, g.updated_at,
				   u.username as created_by_username,
				   COALESCE(member_count.count, 0) as member_count,
				   COALESCE(ug.role, '') as user_role
			FROM grps g
			LEFT JOIN users u ON g.created_by = u.id
			LEFT JOIN (
				SELECT group_id, COUNT(*) as count 
				FROM user_groups 
				GROUP BY group_id
			) member_count ON g.id = member_count.group_id
			LEFT JOIN user_groups ug ON g.id = ug.group_id AND ug.user_id = ?
			ORDER BY g.created_at DESC`
		args = []interface{}{userID}
	} else {
		// 普通用户只能看到自己所属的组
		query = `
			SELECT g.id, g.name, g.description, g.gid, g.created_by, g.created_at, g.updated_at,
				   u.username as created_by_username,
				   COALESCE(member_count.count, 0) as member_count,
				   ug.role as user_role
			FROM grps g
			INNER JOIN user_groups ug ON g.id = ug.group_id
			LEFT JOIN users u ON g.created_by = u.id
			LEFT JOIN (
				SELECT group_id, COUNT(*) as count 
				FROM user_groups 
				GROUP BY group_id
			) member_count ON g.id = member_count.group_id
			WHERE ug.user_id = ?
			ORDER BY g.created_at DESC`
		args = []interface{}{userID}
	}

	rows, err := s.db.Query(query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var groups []models.GroupWithPermissions
	for rows.Next() {
		var g models.GroupWithPermissions
		var userRole sql.NullString

		err := rows.Scan(
			&g.ID, &g.Name, &g.Description, &g.GID, &g.CreatedBy, 
			&g.CreatedAt, &g.UpdatedAt, &g.CreatedByUsername, 
			&g.MemberCount, &userRole,
		)
		if err != nil {
			return nil, err
		}

		if userRole.Valid {
			g.UserRole = userRole.String
		}

		// 设置权限
		g.CanManage = isAdmin || g.CreatedBy == userID || g.UserRole == "admin"
		g.CanAddMembers = g.CanManage
		g.CanRemoveMembers = g.CanManage

		groups = append(groups, g)
	}

	return groups, nil
}

// GetGroupByID 根据ID获取组信息
func (s *GroupService) GetGroupByID(groupID int) (*models.Group, error) {
	query := `
		SELECT g.id, g.name, g.description, g.gid, g.created_by, g.created_at, g.updated_at,
			   u.username as created_by_username,
			   COALESCE(member_count.count, 0) as member_count
		FROM grps g
		LEFT JOIN users u ON g.created_by = u.id
		LEFT JOIN (
			SELECT group_id, COUNT(*) as count 
			FROM user_groups 
			GROUP BY group_id
		) member_count ON g.id = member_count.group_id
		WHERE g.id = ?`

	var group models.Group
	err := s.db.QueryRow(query, groupID).Scan(
		&group.ID, &group.Name, &group.Description, &group.GID, &group.CreatedBy,
		&group.CreatedAt, &group.UpdatedAt, &group.CreatedByUsername, &group.MemberCount,
	)
	if err != nil {
		return nil, err
	}

	return &group, nil
}

// UpdateGroup 更新组信息
func (s *GroupService) UpdateGroup(groupID int, req *models.GroupUpdateRequest, userID int, isAdmin bool) error {
	// 检查权限
	canManage, err := s.CanManageGroup(groupID, userID, isAdmin)
	if err != nil {
		return err
	}
	if !canManage {
		return fmt.Errorf("permission denied")
	}

	// 检查新名称是否与其他组冲突
	var count int
	err = s.db.QueryRow("SELECT COUNT(*) FROM grps WHERE name = ? AND id != ?", req.Name, groupID).Scan(&count)
	if err != nil {
		return err
	}
	if count > 0 {
		return fmt.Errorf("group name '%s' already exists", req.Name)
	}

	_, err = s.db.Exec(`
		UPDATE grps 
		SET name = ?, description = ?
		WHERE id = ?`,
		req.Name, req.Description, groupID)
	
	return err
}

// DeleteGroup 删除组
func (s *GroupService) DeleteGroup(groupID int, userID int, isAdmin bool) error {
	// 获取组信息
	group, err := s.GetGroupByID(groupID)
	if err != nil {
		return err
	}

	// 检查권한
	canManage, err := s.CanManageGroup(groupID, userID, isAdmin)
	if err != nil {
		return err
	}
	if !canManage {
		return fmt.Errorf("permission denied")
	}

	// 开启事务
	tx, err := s.db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()

	// 删除组成员关系
	_, err = tx.Exec("DELETE FROM user_groups WHERE group_id = ?", groupID)
	if err != nil {
		return err
	}

	// 删除组
	_, err = tx.Exec("DELETE FROM grps WHERE id = ?", groupID)
	if err != nil {
		return err
	}

	// 释放 GID
	if err := s.DeallocateGID(group.GID); err != nil {
		// 记录错误但不影响删除操作
		fmt.Printf("Warning: failed to deallocate GID %d: %v\n", group.GID, err)
	}

	// 删除组目录（可选，可能需要手动处理）
	if err := s.RemoveGroupDirectory(group.Name); err != nil {
		fmt.Printf("Warning: failed to remove group directory %s: %v\n", group.Name, err)
	}

	return tx.Commit()
}

// RemoveGroupDirectory 删除组目录
func (s *GroupService) RemoveGroupDirectory(groupName string) error {
	groupsPath := os.Getenv("GROUPS_DATA_PATH")
	if groupsPath == "" {
		groupsPath = "./data/groups"
	}

	groupDir := filepath.Join(groupsPath, groupName)
	return os.RemoveAll(groupDir)
}

// CanManageGroup 检查用户是否可以管理组
func (s *GroupService) CanManageGroup(groupID, userID int, isAdmin bool) (bool, error) {
	if isAdmin {
		return true, nil
	}

	// 检查是否是组创建者
	var createdBy int
	err := s.db.QueryRow("SELECT created_by FROM grps WHERE id = ?", groupID).Scan(&createdBy)
	if err != nil {
		return false, err
	}
	if createdBy == userID {
		return true, nil
	}

	// 检查是否是组管理员
	var role sql.NullString
	err = s.db.QueryRow("SELECT role FROM user_groups WHERE group_id = ? AND user_id = ?", groupID, userID).Scan(&role)
	if err != nil && err != sql.ErrNoRows {
		return false, err
	}
	
	return role.Valid && role.String == "admin", nil
}

// GetUserGroups 获取用户所属的组
func (s *GroupService) GetUserGroups(userID int) ([]models.UserGroup, error) {
	query := `
		SELECT ug.id, ug.user_id, ug.group_id, ug.role, ug.joined_at,
			   g.name as group_name
		FROM user_groups ug
		JOIN grps g ON ug.group_id = g.id
		WHERE ug.user_id = ?
		ORDER BY ug.joined_at DESC`

	rows, err := s.db.Query(query, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var userGroups []models.UserGroup
	for rows.Next() {
		var ug models.UserGroup
		err := rows.Scan(
			&ug.ID, &ug.UserID, &ug.GroupID, &ug.Role, &ug.JoinedAt,
			&ug.GroupName,
		)
		if err != nil {
			return nil, err
		}
		userGroups = append(userGroups, ug)
	}

	return userGroups, nil
}

// IsGroupAdmin 检查用户是否是组管理员
func (s *GroupService) IsGroupAdmin(groupID int, userID int) (bool, error) {
	query := `SELECT role FROM user_groups WHERE group_id = ? AND user_id = ?`
	
	var role string
	err := s.db.QueryRow(query, groupID, userID).Scan(&role)
	if err != nil {
		if err == sql.ErrNoRows {
			return false, nil // 用户不在组中
		}
		return false, err
	}
	
	return role == "admin", nil
}

// CanManageGroupAdvanced 检查用户是否有组的高级管理权限
func (s *GroupService) CanManageGroupAdvanced(groupID int, userID int, isSystemAdmin bool) (bool, error) {
	// 系统管理员有所有权限
	if isSystemAdmin {
		return true, nil
	}
	
	// 检查是否是组管理员
	isGroupAdmin, err := s.IsGroupAdmin(groupID, userID)
	if err != nil {
		return false, err
	}
	
	return isGroupAdmin, nil
}

// GetGroupMembers 获取组成员列表
func (s *GroupService) GetGroupMembers(groupID int, userID int, isAdmin bool) ([]models.UserGroup, error) {
	// 检查访问权限（组成员或管理员可以查看）
	if !isAdmin {
		isMember, err := s.IsGroupMember(groupID, userID)
		if err != nil {
			return nil, err
		}
		if !isMember {
			return nil, fmt.Errorf("permission denied")
		}
	}

	query := `
		SELECT ug.id, ug.user_id, ug.group_id, ug.role, ug.joined_at,
			   u.username, u.email
		FROM user_groups ug
		JOIN users u ON ug.user_id = u.id
		WHERE ug.group_id = ?
		ORDER BY ug.role DESC, ug.joined_at ASC`

	rows, err := s.db.Query(query, groupID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var members []models.UserGroup
	for rows.Next() {
		var member models.UserGroup
		err := rows.Scan(
			&member.ID, &member.UserID, &member.GroupID, &member.Role, &member.JoinedAt,
			&member.Username, &member.UserEmail,
		)
		if err != nil {
			return nil, err
		}
		members = append(members, member)
	}

	return members, nil
}

// AddGroupMember 添加组成员
func (s *GroupService) AddGroupMember(groupID int, req *models.AddMemberRequest, userID int, isAdmin bool) error {
	// 检查管理权限
	canManage, err := s.CanManageGroup(groupID, userID, isAdmin)
	if err != nil {
		return err
	}
	if !canManage {
		return fmt.Errorf("permission denied")
	}

	// 检查用户是否存在
	var userExists bool
	err = s.db.QueryRow("SELECT EXISTS(SELECT 1 FROM users WHERE id = ?)", req.UserID).Scan(&userExists)
	if err != nil {
		return err
	}
	if !userExists {
		return fmt.Errorf("user not found")
	}

	// 检查是否已经是组成员
	var count int
	err = s.db.QueryRow("SELECT COUNT(*) FROM user_groups WHERE group_id = ? AND user_id = ?", groupID, req.UserID).Scan(&count)
	if err != nil {
		return err
	}
	if count > 0 {
		return fmt.Errorf("user is already a member of this group")
	}

	// 添加成员
	_, err = s.db.Exec(`
		INSERT INTO user_groups (user_id, group_id, role) 
		VALUES (?, ?, ?)`,
		req.UserID, groupID, req.Role)
	
	return err
}

// RemoveGroupMember 移除组成员
func (s *GroupService) RemoveGroupMember(groupID, memberUserID, userID int, isAdmin bool) error {
	// 检查管理权限
	canManage, err := s.CanManageGroup(groupID, userID, isAdmin)
	if err != nil {
		return err
	}
	if !canManage {
		return fmt.Errorf("permission denied")
	}

	// 检查是否试图移除组创建者
	var createdBy int
	err = s.db.QueryRow("SELECT created_by FROM grps WHERE id = ?", groupID).Scan(&createdBy)
	if err != nil {
		return err
	}
	if createdBy == memberUserID {
		return fmt.Errorf("cannot remove group creator")
	}

	// 移除成员
	result, err := s.db.Exec("DELETE FROM user_groups WHERE group_id = ? AND user_id = ?", groupID, memberUserID)
	if err != nil {
		return err
	}

	rowsAffected, err := result.RowsAffected()
	if err != nil {
		return err
	}
	if rowsAffected == 0 {
		return fmt.Errorf("user is not a member of this group")
	}

	return nil
}

// UpdateMemberRole 更新成员角色
func (s *GroupService) UpdateMemberRole(groupID, memberUserID, userID int, req *models.UpdateMemberRequest, isAdmin bool) error {
	// 检查管理权限
	canManage, err := s.CanManageGroup(groupID, userID, isAdmin)
	if err != nil {
		return err
	}
	if !canManage {
		return fmt.Errorf("permission denied")
	}

	// 检查是否试图修改组创建者角色
	var createdBy int
	err = s.db.QueryRow("SELECT created_by FROM grps WHERE id = ?", groupID).Scan(&createdBy)
	if err != nil {
		return err
	}
	if createdBy == memberUserID {
		return fmt.Errorf("cannot modify group creator role")
	}

	// 更新角色
	result, err := s.db.Exec(`
		UPDATE user_groups 
		SET role = ? 
		WHERE group_id = ? AND user_id = ?`,
		req.Role, groupID, memberUserID)
	if err != nil {
		return err
	}

	rowsAffected, err := result.RowsAffected()
	if err != nil {
		return err
	}
	if rowsAffected == 0 {
		return fmt.Errorf("user is not a member of this group")
	}

	return nil
}

// IsGroupMember 检查用户是否是组成员
func (s *GroupService) IsGroupMember(groupID, userID int) (bool, error) {
	var count int
	err := s.db.QueryRow("SELECT COUNT(*) FROM user_groups WHERE group_id = ? AND user_id = ?", groupID, userID).Scan(&count)
	if err != nil {
		return false, err
	}
	return count > 0, nil
}

// GetGroupsForContainer 获取用户容器需要挂载的组目录信息
func (s *GroupService) GetGroupsForContainer(userID int) ([]models.Group, error) {
	query := `
		SELECT g.id, g.name, g.gid
		FROM grps g
		INNER JOIN user_groups ug ON g.id = ug.group_id
		WHERE ug.user_id = ?
		ORDER BY g.name`

	rows, err := s.db.Query(query, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var groups []models.Group
	for rows.Next() {
		var group models.Group
		err := rows.Scan(&group.ID, &group.Name, &group.GID)
		if err != nil {
			return nil, err
		}
		groups = append(groups, group)
	}

	return groups, nil
}

// GetGroupsWithRolesForContainer 获取用户容器需要挂载的组目录信息，包含用户在各组中的角色
func (s *GroupService) GetGroupsWithRolesForContainer(userID int) ([]models.Group, []string, error) {
	query := `
		SELECT g.id, g.name, g.gid, ug.role
		FROM grps g
		INNER JOIN user_groups ug ON g.id = ug.group_id
		WHERE ug.user_id = ?
		ORDER BY g.name`

	rows, err := s.db.Query(query, userID)
	if err != nil {
		return nil, nil, err
	}
	defer rows.Close()

	var groups []models.Group
	var roles []string
	for rows.Next() {
		var group models.Group
		var role string
		err := rows.Scan(&group.ID, &group.Name, &group.GID, &role)
		if err != nil {
			return nil, nil, err
		}
		groups = append(groups, group)
		roles = append(roles, role)
	}

	return groups, roles, nil
}