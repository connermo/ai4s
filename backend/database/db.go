package database

import (
	"database/sql"
	"fmt"
	"io/ioutil"
	"strings"
	
	_ "github.com/go-sql-driver/mysql"
)

var DB *sql.DB

func InitDB(dataSourceName string) error {
	var err error
	DB, err = sql.Open("mysql", dataSourceName)
	if err != nil {
		return fmt.Errorf("failed to open database: %v", err)
	}

	if err = DB.Ping(); err != nil {
		return fmt.Errorf("failed to ping database: %v", err)
	}

	// 创建表结构
	if err = createTables(); err != nil {
		return fmt.Errorf("failed to create tables: %v", err)
	}

	return nil
}

func createTables() error {
	// 先执行基础表和数据初始化
	if err := executeSQL("database/init.sql"); err != nil {
		return fmt.Errorf("failed to initialize tables: %v", err)
	}

	// 确保所有核心表都存在（防御性编程）
	if err := ensureTablesExist(); err != nil {
		return fmt.Errorf("failed to ensure tables exist: %v", err)
	}

	// 检查是否已经创建了索引
	var count int
	err := DB.QueryRow("SELECT COUNT(*) FROM db_init_status WHERE component = 'indexes' AND initialized = TRUE").Scan(&count)
	
	// 如果查询出错或者计数为0，需要创建索引
	if err != nil || count == 0 {
		if err := executeIndexes(); err != nil {
			return fmt.Errorf("failed to create indexes: %v", err)
		}
		
		// 标记索引已创建
		_, err = DB.Exec("INSERT INTO db_init_status (component, initialized) VALUES ('indexes', TRUE) ON DUPLICATE KEY UPDATE initialized = TRUE")
		if err != nil {
			return fmt.Errorf("failed to mark indexes as initialized: %v", err)
		}
	}

	return nil
}

func ensureTablesExist() error {
	// 确保状态表存在
	_, err := DB.Exec(`CREATE TABLE IF NOT EXISTS db_init_status (
		id INT AUTO_INCREMENT PRIMARY KEY,
		component VARCHAR(50) UNIQUE NOT NULL,
		initialized BOOLEAN DEFAULT FALSE,
		created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
	)`)
	if err != nil {
		return fmt.Errorf("failed to create status table: %v", err)
	}

	// 确保用户表存在
	_, err = DB.Exec(`CREATE TABLE IF NOT EXISTS users (
		id INT AUTO_INCREMENT PRIMARY KEY,
		username VARCHAR(50) UNIQUE NOT NULL,
		password VARCHAR(255) NOT NULL,
		email VARCHAR(100),
		is_active BOOLEAN DEFAULT TRUE,
		is_admin BOOLEAN DEFAULT FALSE,
		created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
		updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
		container_id VARCHAR(64),
		base_port INT UNIQUE,
		last_login TIMESTAMP NULL
	)`)
	if err != nil {
		return fmt.Errorf("failed to create users table: %v", err)
	}

	// 确保容器表存在
	_, err = DB.Exec(`CREATE TABLE IF NOT EXISTS containers (
		id VARCHAR(64) PRIMARY KEY,
		user_id INT NOT NULL,
		name VARCHAR(100) NOT NULL,
		status VARCHAR(20) DEFAULT 'stopped',
		image_name VARCHAR(200) DEFAULT 'gpu-dev-env:latest',
		cpu_limit VARCHAR(20) DEFAULT '2',
		memory_limit VARCHAR(20) DEFAULT '4g',
		gpu_devices VARCHAR(100),
		created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
		updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
		last_seen TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
		FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
	)`)
	if err != nil {
		return fmt.Errorf("failed to create containers table: %v", err)
	}

	// 确保容器统计表存在
	_, err = DB.Exec(`CREATE TABLE IF NOT EXISTS container_stats (
		id INT AUTO_INCREMENT PRIMARY KEY,
		container_id VARCHAR(64) NOT NULL,
		cpu_usage DECIMAL(5,2) DEFAULT 0,
		memory_usage BIGINT DEFAULT 0,
		gpu_usage DECIMAL(5,2) DEFAULT 0,
		timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
		FOREIGN KEY (container_id) REFERENCES containers (id) ON DELETE CASCADE
	)`)
	if err != nil {
		return fmt.Errorf("failed to create container_stats table: %v", err)
	}

	// 确保默认管理员用户存在
	_, err = DB.Exec(`INSERT IGNORE INTO users (username, password, email, is_admin, base_port) 
		VALUES ('admin', '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'admin@example.com', TRUE, 9001)`)
	if err != nil {
		return fmt.Errorf("failed to create default admin user: %v", err)
	}

	return nil
}

func executeSQL(filename string) error {
	content, err := ioutil.ReadFile(filename)
	if err != nil {
		return fmt.Errorf("failed to read file %s: %v", filename, err)
	}

	statements := strings.Split(string(content), ";")
	for _, stmt := range statements {
		stmt = strings.TrimSpace(stmt)
		if stmt == "" || strings.HasPrefix(stmt, "--") {
			continue
		}
		
		_, err = DB.Exec(stmt)
		if err != nil {
			return fmt.Errorf("failed to execute statement '%s': %v", stmt, err)
		}
	}
	return nil
}

func executeIndexes() error {
	content, err := ioutil.ReadFile("database/indexes.sql")
	if err != nil {
		return fmt.Errorf("failed to read indexes file: %v", err)
	}

	statements := strings.Split(string(content), ";")
	for _, stmt := range statements {
		stmt = strings.TrimSpace(stmt)
		if stmt == "" || strings.HasPrefix(stmt, "--") {
			continue
		}
		
		_, err = DB.Exec(stmt)
		if err != nil {
			// 忽略索引已存在的错误
			if strings.Contains(err.Error(), "Duplicate key name") {
				continue
			}
			return fmt.Errorf("failed to create index '%s': %v", stmt, err)
		}
	}
	return nil
}

func Close() error {
	if DB != nil {
		return DB.Close()
	}
	return nil
}