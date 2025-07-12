package database

import (
	"database/sql"
	"fmt"
	"io/ioutil"
	"path/filepath"
	
	_ "github.com/mattn/go-sqlite3"
)

var DB *sql.DB

func InitDB(dataSourceName string) error {
	var err error
	DB, err = sql.Open("sqlite3", dataSourceName)
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
	schemaFile := filepath.Join("database", "schema.sql")
	schema, err := ioutil.ReadFile(schemaFile)
	if err != nil {
		return fmt.Errorf("failed to read schema file: %v", err)
	}

	_, err = DB.Exec(string(schema))
	if err != nil {
		return fmt.Errorf("failed to execute schema: %v", err)
	}

	return nil
}

func Close() error {
	if DB != nil {
		return DB.Close()
	}
	return nil
}