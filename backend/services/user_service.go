package services

import (
	"database/sql"
	"fmt"
	"time"
	
	"gpu-dev-platform/database"
	"gpu-dev-platform/models"
)

type UserService struct {
	db *sql.DB
}

func NewUserService() *UserService {
	return &UserService{db: database.DB}
}

func (s *UserService) CreateUser(username, password, email string) (*models.User, error) {
	user := &models.User{
		Username:  username,
		Email:     email,
		IsActive:  true,
		IsAdmin:   false,
		CreatedAt: time.Now(),
		UpdatedAt: time.Now(),
	}

	if err := user.HashPassword(password); err != nil {
		return nil, err
	}

	// 分配端口
	basePort, err := s.allocatePort()
	if err != nil {
		return nil, err
	}
	user.BasePort = basePort

	query := `
		INSERT INTO users (username, password, email, is_active, is_admin, created_at, updated_at, base_port)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?)
	`
	
	result, err := s.db.Exec(query, user.Username, user.Password, user.Email, 
		user.IsActive, user.IsAdmin, user.CreatedAt, user.UpdatedAt, user.BasePort)
	if err != nil {
		return nil, err
	}

	id, err := result.LastInsertId()
	if err != nil {
		return nil, err
	}
	user.ID = int(id)

	return user, nil
}

func (s *UserService) GetUserByID(id int) (*models.User, error) {
	user := &models.User{}
	query := `
		SELECT id, username, password, email, is_active, is_admin, 
		       created_at, updated_at, COALESCE(container_id, ''), 
		       base_port, COALESCE(last_login, created_at)
		FROM users WHERE id = ?
	`
	
	err := s.db.QueryRow(query, id).Scan(
		&user.ID, &user.Username, &user.Password, &user.Email,
		&user.IsActive, &user.IsAdmin, &user.CreatedAt, &user.UpdatedAt,
		&user.ContainerID, &user.BasePort, &user.LastLogin,
	)
	
	if err != nil {
		return nil, err
	}
	
	return user, nil
}

func (s *UserService) GetUserByUsername(username string) (*models.User, error) {
	user := &models.User{}
	query := `
		SELECT id, username, password, email, is_active, is_admin, 
		       created_at, updated_at, COALESCE(container_id, ''), 
		       base_port, COALESCE(last_login, created_at)
		FROM users WHERE username = ?
	`
	
	err := s.db.QueryRow(query, username).Scan(
		&user.ID, &user.Username, &user.Password, &user.Email,
		&user.IsActive, &user.IsAdmin, &user.CreatedAt, &user.UpdatedAt,
		&user.ContainerID, &user.BasePort, &user.LastLogin,
	)
	
	if err != nil {
		return nil, err
	}
	
	return user, nil
}

func (s *UserService) ListUsers() ([]*models.User, error) {
	query := `
		SELECT id, username, password, email, is_active, is_admin, 
		       created_at, updated_at, COALESCE(container_id, ''), 
		       base_port, COALESCE(last_login, created_at)
		FROM users ORDER BY created_at DESC
	`
	
	rows, err := s.db.Query(query)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	
	var users []*models.User
	for rows.Next() {
		user := &models.User{}
		err := rows.Scan(
			&user.ID, &user.Username, &user.Password, &user.Email,
			&user.IsActive, &user.IsAdmin, &user.CreatedAt, &user.UpdatedAt,
			&user.ContainerID, &user.BasePort, &user.LastLogin,
		)
		if err != nil {
			return nil, err
		}
		users = append(users, user)
	}
	
	return users, nil
}

func (s *UserService) UpdateUser(id int, updates map[string]interface{}) error {
	if len(updates) == 0 {
		return nil
	}
	
	setParts := []string{}
	args := []interface{}{}
	
	for field, value := range updates {
		if field == "password" {
			user := &models.User{}
			if err := user.HashPassword(value.(string)); err != nil {
				return err
			}
			value = user.Password
		}
		setParts = append(setParts, field+" = ?")
		args = append(args, value)
	}
	
	setParts = append(setParts, "updated_at = ?")
	args = append(args, time.Now())
	args = append(args, id)
	
	query := fmt.Sprintf("UPDATE users SET %s WHERE id = ?", 
		fmt.Sprintf("%s", setParts))
	
	_, err := s.db.Exec(query, args...)
	return err
}

func (s *UserService) DeleteUser(id int) error {
	_, err := s.db.Exec("DELETE FROM users WHERE id = ?", id)
	return err
}

func (s *UserService) UpdateLastLogin(userID int) error {
	_, err := s.db.Exec("UPDATE users SET last_login = ? WHERE id = ?", 
		time.Now(), userID)
	return err
}

// allocatePort 分配可用端口
func (s *UserService) allocatePort() (int, error) {
	var maxPort sql.NullInt64
	err := s.db.QueryRow("SELECT MAX(base_port) FROM users").Scan(&maxPort)
	if err != nil && err != sql.ErrNoRows {
		return 0, err
	}
	
	if !maxPort.Valid {
		return 9001, nil // 起始端口
	}
	
	return int(maxPort.Int64) + 10, nil // 每用户预留10个端口
}