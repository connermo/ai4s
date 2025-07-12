package main

import (
	"log"
	"net/http"
	"os"

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

	// 用户管理路由
	userHandler := handlers.NewUserHandler()
	api.HandleFunc("/users", userHandler.ListUsers).Methods("GET")
	api.HandleFunc("/users", userHandler.CreateUser).Methods("POST")
	api.HandleFunc("/users/{id:[0-9]+}", userHandler.GetUser).Methods("GET")
	api.HandleFunc("/users/{id:[0-9]+}", userHandler.UpdateUser).Methods("PUT")
	api.HandleFunc("/users/{id:[0-9]+}", userHandler.DeleteUser).Methods("DELETE")
	api.HandleFunc("/users/{id:[0-9]+}/password", userHandler.ChangePassword).Methods("PUT")

	// 容器管理路由
	containerHandler, err := handlers.NewContainerHandler()
	if err != nil {
		log.Fatal("Failed to create container handler:", err)
	}
	
	api.HandleFunc("/containers", containerHandler.ListContainers).Methods("GET")
	api.HandleFunc("/containers", containerHandler.CreateContainer).Methods("POST")
	api.HandleFunc("/containers/{id}", containerHandler.GetContainer).Methods("GET")
	api.HandleFunc("/containers/{id}/start", containerHandler.StartContainer).Methods("POST")
	api.HandleFunc("/containers/{id}/stop", containerHandler.StopContainer).Methods("POST")
	api.HandleFunc("/containers/{id}", containerHandler.RemoveContainer).Methods("DELETE")
	api.HandleFunc("/users/{userId:[0-9]+}/container", containerHandler.GetUserContainer).Methods("GET")

	// 静态文件服务
	router.PathPrefix("/static/").Handler(http.StripPrefix("/static/", 
		http.FileServer(http.Dir("./static/"))))

	// 前端路由 (如果没有API路径，则服务前端)
	router.PathPrefix("/").HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		http.ServeFile(w, r, "./templates/index.html")
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