package handlers

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"net/http"
	"strconv"
	"strings"
	"time"

	"gpu-dev-platform/database"
	"gpu-dev-platform/models"
	"github.com/golang-jwt/jwt/v5"
	"golang.org/x/crypto/bcrypt"
)

type AuthHandler struct {
	db *sql.DB
}

type LoginRequest struct {
	Username string `json:"username"`
	Password string `json:"password"`
}

type LoginResponse struct {
	Token string       `json:"token"`
	User  *models.User `json:"user"`
}

type Claims struct {
	UserID   int    `json:"user_id"`
	Username string `json:"username"`
	IsAdmin  bool   `json:"is_admin"`
	jwt.RegisteredClaims
}

// JWT密钥 - 在生产环境中应该从环境变量获取
var jwtSecret = []byte("your-secret-key-change-in-production")

func NewAuthHandler() *AuthHandler {
	return &AuthHandler{
		db: database.DB,
	}
}

// 管理员登录
func (h *AuthHandler) AdminLogin(w http.ResponseWriter, r *http.Request) {
	var req LoginRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "无效的请求格式", http.StatusBadRequest)
		return
	}

	if req.Username == "" || req.Password == "" {
		http.Error(w, "用户名和密码不能为空", http.StatusBadRequest)
		return
	}

	// 查询用户
	user := &models.User{}
	query := `SELECT id, username, email, password, is_active, is_admin, 
	          created_at, updated_at, COALESCE(container_id, '') as container_id 
	          FROM users WHERE username = ? AND is_admin = 1`
	
	err := h.db.QueryRow(query, req.Username).Scan(
		&user.ID, &user.Username, &user.Email, &user.Password,
		&user.IsActive, &user.IsAdmin, &user.CreatedAt, &user.UpdatedAt,
		&user.ContainerID,
	)

	if err != nil {
		if err == sql.ErrNoRows {
			http.Error(w, "管理员账户不存在", http.StatusUnauthorized)
		} else {
			http.Error(w, "数据库查询失败", http.StatusInternalServerError)
		}
		return
	}

	// 检查用户是否激活
	if !user.IsActive {
		http.Error(w, "管理员账户已被禁用", http.StatusUnauthorized)
		return
	}

	// 验证密码
	if err := bcrypt.CompareHashAndPassword([]byte(user.Password), []byte(req.Password)); err != nil {
		http.Error(w, "用户名或密码错误", http.StatusUnauthorized)
		return
	}

	// 生成JWT token
	token, err := h.generateToken(user)
	if err != nil {
		http.Error(w, "生成token失败", http.StatusInternalServerError)
		return
	}

	// 清除密码hash，不返回给客户端
	user.Password = ""

	response := LoginResponse{
		Token: token,
		User:  user,
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

// 用户登录
func (h *AuthHandler) Login(w http.ResponseWriter, r *http.Request) {
	var req LoginRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "无效的请求格式", http.StatusBadRequest)
		return
	}

	if req.Username == "" || req.Password == "" {
		http.Error(w, "用户名和密码不能为空", http.StatusBadRequest)
		return
	}

	// 查询用户
	user := &models.User{}
	query := `SELECT id, username, email, password, is_active, is_admin, 
	          created_at, updated_at, COALESCE(container_id, '') as container_id 
	          FROM users WHERE username = ?`
	
	err := h.db.QueryRow(query, req.Username).Scan(
		&user.ID, &user.Username, &user.Email, &user.Password,
		&user.IsActive, &user.IsAdmin, &user.CreatedAt, &user.UpdatedAt,
		&user.ContainerID,
	)

	if err != nil {
		if err == sql.ErrNoRows {
			http.Error(w, "用户名或密码错误", http.StatusUnauthorized)
		} else {
			http.Error(w, "数据库查询失败", http.StatusInternalServerError)
		}
		return
	}

	// 检查用户是否激活
	if !user.IsActive {
		http.Error(w, "用户账户已被禁用", http.StatusUnauthorized)
		return
	}

	// 验证密码
	if err := bcrypt.CompareHashAndPassword([]byte(user.Password), []byte(req.Password)); err != nil {
		http.Error(w, "用户名或密码错误", http.StatusUnauthorized)
		return
	}

	// 生成JWT token
	token, err := h.generateToken(user)
	if err != nil {
		http.Error(w, "生成token失败", http.StatusInternalServerError)
		return
	}

	// 清除密码hash，不返回给客户端
	user.Password = ""

	response := LoginResponse{
		Token: token,
		User:  user,
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

// 生成JWT token
func (h *AuthHandler) generateToken(user *models.User) (string, error) {
	claims := Claims{
		UserID:   user.ID,
		Username: user.Username,
		IsAdmin:  user.IsAdmin,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(24 * time.Hour)), // 24小时过期
			IssuedAt:  jwt.NewNumericDate(time.Now()),
			NotBefore: jwt.NewNumericDate(time.Now()),
		},
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString(jwtSecret)
}

// 验证JWT token
func (h *AuthHandler) ValidateToken(tokenString string) (*Claims, error) {
	token, err := jwt.ParseWithClaims(tokenString, &Claims{}, func(token *jwt.Token) (interface{}, error) {
		if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, fmt.Errorf("unexpected signing method: %v", token.Header["alg"])
		}
		return jwtSecret, nil
	})

	if err != nil {
		return nil, err
	}

	if claims, ok := token.Claims.(*Claims); ok && token.Valid {
		return claims, nil
	}

	return nil, fmt.Errorf("invalid token")
}

// 认证中间件
func (h *AuthHandler) RequireAuth(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		authHeader := r.Header.Get("Authorization")
		if authHeader == "" {
			http.Error(w, "缺少Authorization头", http.StatusUnauthorized)
			return
		}

		// 检查Bearer token格式
		parts := strings.SplitN(authHeader, " ", 2)
		if len(parts) != 2 || parts[0] != "Bearer" {
			http.Error(w, "无效的Authorization格式", http.StatusUnauthorized)
			return
		}

		tokenString := parts[1]
		claims, err := h.ValidateToken(tokenString)
		if err != nil {
			http.Error(w, "无效的token", http.StatusUnauthorized)
			return
		}

		// 将用户信息添加到请求上下文
		r.Header.Set("X-User-ID", strconv.Itoa(claims.UserID))
		r.Header.Set("X-Username", claims.Username)
		r.Header.Set("X-Is-Admin", strconv.FormatBool(claims.IsAdmin))

		next(w, r)
	}
}

// 只允许管理员访问的中间件
func (h *AuthHandler) RequireAdmin(next http.HandlerFunc) http.HandlerFunc {
	return h.RequireAuth(func(w http.ResponseWriter, r *http.Request) {
		isAdmin := r.Header.Get("X-Is-Admin") == "true"
		if !isAdmin {
			http.Error(w, "需要管理员权限", http.StatusForbidden)
			return
		}
		next(w, r)
	})
}