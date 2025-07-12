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

	// 确保状态表存在（防御性编程）
	_, err := DB.Exec(`CREATE TABLE IF NOT EXISTS db_init_status (
		id INT AUTO_INCREMENT PRIMARY KEY,
		component VARCHAR(50) UNIQUE NOT NULL,
		initialized BOOLEAN DEFAULT FALSE,
		created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
	)`)
	if err != nil {
		return fmt.Errorf("failed to ensure status table exists: %v", err)
	}

	// 检查是否已经创建了索引
	var count int
	err = DB.QueryRow("SELECT COUNT(*) FROM db_init_status WHERE component = 'indexes' AND initialized = TRUE").Scan(&count)
	
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