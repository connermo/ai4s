package models

import (
	"time"
	"golang.org/x/crypto/bcrypt"
)

type User struct {
	ID          int       `json:"id" db:"id"`
	Username    string    `json:"username" db:"username"`
	Password    string    `json:"-" db:"password"`
	Email       string    `json:"email" db:"email"`
	IsActive    bool      `json:"is_active" db:"is_active"`
	IsAdmin     bool      `json:"is_admin" db:"is_admin"`
	CreatedAt   time.Time `json:"created_at" db:"created_at"`
	UpdatedAt   time.Time `json:"updated_at" db:"updated_at"`
	
	// 容器相关信息
	ContainerID string    `json:"container_id" db:"container_id"`
	BasePort    int       `json:"base_port" db:"base_port"` // SSH端口基数
	LastLogin   time.Time `json:"last_login" db:"last_login"`
}

// HashPassword 加密密码
func (u *User) HashPassword(password string) error {
	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		return err
	}
	u.Password = string(hashedPassword)
	return nil
}

// CheckPassword 验证密码
func (u *User) CheckPassword(password string) bool {
	err := bcrypt.CompareHashAndPassword([]byte(u.Password), []byte(password))
	return err == nil
}

// GetPorts 获取用户的服务端口
func (u *User) GetPorts() map[string]int {
	return map[string]int{
		"ssh":         u.BasePort + 0,   // 末尾0: SSH
		"vscode":      u.BasePort + 1,   // 末尾1: VSCode
		"jupyter":     u.BasePort + 2,   // 末尾2: Jupyter
		"tensorboard": u.BasePort + 3,   // 末尾3: TensorBoard
		"app1":        u.BasePort + 4,   // 末尾4: 备用应用1
		"app2":        u.BasePort + 5,   // 末尾5: 备用应用2
		"app3":        u.BasePort + 6,   // 末尾6: 备用应用3
		"app4":        u.BasePort + 7,   // 末尾7: 备用应用4
		"app5":        u.BasePort + 8,   // 末尾8: 备用应用5
		"app6":        u.BasePort + 9,   // 末尾9: 备用应用6
	}
}