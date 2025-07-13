package main

import (
	"log"
	"net/http"
	"os"
	"path/filepath"

	"gpu-dev-platform/database"
	"gpu-dev-platform/handlers"
	"github.com/gorilla/mux"
	"github.com/rs/cors"
)

func main() {
	// 初始化数据库
	dbDSN := os.Getenv("DB_DSN")
	if dbDSN == "" {
		dbDSN = "root:password@tcp(mysql:3306)/gpu_platform?charset=utf8mb4&parseTime=True&loc=Local"
	}
	if err := database.InitDB(dbDSN); err != nil {
		log.Fatal("Failed to initialize database:", err)
	}
	defer database.Close()

	// 创建路由
	router := mux.NewRouter()

	// API 路由
	api := router.PathPrefix("/api").Subrouter()

	// 认证处理器
	authHandler := handlers.NewAuthHandler()
	
	// 用户自助服务处理器
	userSelfHandler, err := handlers.NewUserSelfHandler()
	if err != nil {
		log.Fatal("Failed to create user self handler:", err)
	}

	// 公开的认证路由
	api.HandleFunc("/user/login", authHandler.Login).Methods("POST")
	api.HandleFunc("/admin/login", authHandler.AdminLogin).Methods("POST")

	// 用户自助路由 (需要认证)
	userAPI := api.PathPrefix("/user").Subrouter()
	userAPI.HandleFunc("/info", authHandler.RequireAuth(userSelfHandler.GetSelfInfo)).Methods("GET")
	userAPI.HandleFunc("/container", authHandler.RequireAuth(userSelfHandler.GetSelfContainer)).Methods("GET")
	userAPI.HandleFunc("/container/reset-password", authHandler.RequireAuth(userSelfHandler.ResetContainerPassword)).Methods("PUT")

	// 管理员路由 (需要管理员权限)
	adminAPI := api.PathPrefix("").Subrouter()
	
	// 用户管理路由
	userHandler := handlers.NewUserHandler()
	adminAPI.HandleFunc("/users", authHandler.RequireAdmin(userHandler.ListUsers)).Methods("GET")
	adminAPI.HandleFunc("/users", authHandler.RequireAdmin(userHandler.CreateUser)).Methods("POST")
	adminAPI.HandleFunc("/users/{id:[0-9]+}", authHandler.RequireAdmin(userHandler.GetUser)).Methods("GET")
	adminAPI.HandleFunc("/users/{id:[0-9]+}", authHandler.RequireAdmin(userHandler.UpdateUser)).Methods("PUT")
	adminAPI.HandleFunc("/users/{id:[0-9]+}", authHandler.RequireAdmin(userHandler.DeleteUser)).Methods("DELETE")
	adminAPI.HandleFunc("/users/{id:[0-9]+}/password", authHandler.RequireAdmin(userHandler.ChangePassword)).Methods("PUT")

	// 容器管理路由
	containerHandler, err := handlers.NewContainerHandler()
	if err != nil {
		log.Fatal("Failed to create container handler:", err)
	}
	
	adminAPI.HandleFunc("/containers", authHandler.RequireAdmin(containerHandler.ListContainers)).Methods("GET")
	adminAPI.HandleFunc("/containers", authHandler.RequireAdmin(containerHandler.CreateContainer)).Methods("POST")
	adminAPI.HandleFunc("/containers/{id}", authHandler.RequireAuth(containerHandler.GetContainer)).Methods("GET")
	adminAPI.HandleFunc("/containers/{id}/status", authHandler.RequireAdmin(containerHandler.GetContainerStatus)).Methods("GET")
	adminAPI.HandleFunc("/containers/{id}/start", authHandler.RequireAdmin(containerHandler.StartContainer)).Methods("POST")
	adminAPI.HandleFunc("/containers/{id}/stop", authHandler.RequireAdmin(containerHandler.StopContainer)).Methods("POST")
	adminAPI.HandleFunc("/containers/{id}", authHandler.RequireAdmin(containerHandler.RemoveContainer)).Methods("DELETE")
	adminAPI.HandleFunc("/containers/{id}/reset-password", authHandler.RequireAdmin(containerHandler.ResetContainerPassword)).Methods("PUT")
	adminAPI.HandleFunc("/users/{userId:[0-9]+}/container", authHandler.RequireAuth(containerHandler.GetUserContainer)).Methods("GET")

	// 静态文件服务
	router.PathPrefix("/static/").Handler(http.StripPrefix("/static/", 
		http.FileServer(http.Dir("./static/"))))

	// 前端页面路由
	router.HandleFunc("/user-login", func(w http.ResponseWriter, r *http.Request) {
		http.ServeFile(w, r, "./templates/user-login.html")
	})
	
	router.HandleFunc("/user-dashboard", func(w http.ResponseWriter, r *http.Request) {
		http.ServeFile(w, r, "./templates/user-dashboard.html")
	})
	
	router.HandleFunc("/admin-login", func(w http.ResponseWriter, r *http.Request) {
		http.ServeFile(w, r, "./templates/admin-login.html")
	})
	
	router.HandleFunc("/admin", func(w http.ResponseWriter, r *http.Request) {
		// 简单的前端认证检查（实际的API调用仍然需要后端验证）
		// 这里只是为了用户体验，真正的安全由API认证保障
		http.ServeFile(w, r, "./templates/index.html")
	})

	// 默认路由 - 重定向到用户登录页面
	router.PathPrefix("/").HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// 如果访问根路径，重定向到用户登录页面
		if r.URL.Path == "/" {
			http.Redirect(w, r, "/user-login", http.StatusFound)
			return
		}
		// 其他未匹配路径返回404
		http.NotFound(w, r)
	})

	// CORS设置
	c := cors.New(cors.Options{
		AllowedOrigins: []string{"*"},
		AllowedMethods: []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
		AllowedHeaders: []string{"*"},
	})

	handler := c.Handler(router)

	// 启动服务器
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	log.Printf("Server starting on port %s", port)
	log.Fatal(http.ListenAndServe(":"+port, handler))
}