package store

import (
	"context"
	"database/sql"
	"fmt"
	"time"

	_ "github.com/go-sql-driver/mysql"
)

// Store wraps the MySQL connection used for persisting samples and settings.
type Store struct {
	db *sql.DB
}

func New(dsn string) (*Store, error) {
	db, err := sql.Open("mysql", dsn)
	if err != nil {
		return nil, err
	}
	db.SetMaxOpenConns(10)
	db.SetMaxIdleConns(5)
	db.SetConnMaxLifetime(time.Hour)

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := db.PingContext(ctx); err != nil {
		return nil, fmt.Errorf("ping mysql: %w", err)
	}
	return &Store{db: db}, nil
}

func (s *Store) Close() error { return s.db.Close() }

func (s *Store) DB() *sql.DB { return s.db }

// Migrate creates the schema if it does not exist yet.
func (s *Store) Migrate(ctx context.Context) error {
	stmts := []string{
		`CREATE DATABASE IF NOT EXISTS dashboard DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci`,
		`CREATE TABLE IF NOT EXISTS metric_samples (
			id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
			host VARCHAR(191) NOT NULL,
			collected_at DATETIME(3) NOT NULL,
			cpu_percent DOUBLE NOT NULL DEFAULT 0,
			mem_used BIGINT NOT NULL DEFAULT 0,
			mem_total BIGINT NOT NULL DEFAULT 0,
			disk_used BIGINT NOT NULL DEFAULT 0,
			disk_total BIGINT NOT NULL DEFAULT 0,
			net_rx BIGINT NOT NULL DEFAULT 0,
			net_tx BIGINT NOT NULL DEFAULT 0,
			temp_c DOUBLE NULL,
			load1 DOUBLE NOT NULL DEFAULT 0,
			PRIMARY KEY (id),
			KEY idx_host_time (host, collected_at)
		) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4`,

		`CREATE TABLE IF NOT EXISTS volumes (
			id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
			host VARCHAR(191) NOT NULL,
			mountpoint VARCHAR(255) NOT NULL,
			device VARCHAR(255) NOT NULL DEFAULT '',
			fs_type VARCHAR(64) NOT NULL DEFAULT '',
			total BIGINT NOT NULL DEFAULT 0,
			used BIGINT NOT NULL DEFAULT 0,
			updated_at DATETIME(3) NOT NULL,
			PRIMARY KEY (id),
			UNIQUE KEY uk_host_mount (host, mountpoint)
		) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4`,

		`CREATE TABLE IF NOT EXISTS services (
			id VARCHAR(191) NOT NULL,
			host VARCHAR(191) NOT NULL,
			name VARCHAR(191) NOT NULL,
			image VARCHAR(255) NOT NULL DEFAULT '',
			state VARCHAR(32) NOT NULL DEFAULT 'unknown',
			status VARCHAR(255) NOT NULL DEFAULT '',
			port VARCHAR(64) NOT NULL DEFAULT '',
			started_at DATETIME(3) NULL,
			updated_at DATETIME(3) NOT NULL,
			PRIMARY KEY (id),
			KEY idx_host (host)
		) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4`,

		`CREATE TABLE IF NOT EXISTS disks (
			id VARCHAR(191) NOT NULL,
			host VARCHAR(191) NOT NULL,
			name VARCHAR(191) NOT NULL,
			model VARCHAR(255) NOT NULL DEFAULT '',
			serial VARCHAR(191) NOT NULL DEFAULT '',
			size BIGINT NOT NULL DEFAULT 0,
			temperature DOUBLE NULL,
			health VARCHAR(32) NOT NULL DEFAULT 'unknown',
			smart_ok TINYINT(1) NOT NULL DEFAULT 0,
			updated_at DATETIME(3) NOT NULL,
			PRIMARY KEY (id),
			KEY idx_host (host)
		) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4`,

		`CREATE TABLE IF NOT EXISTS hosts (
			host VARCHAR(191) NOT NULL,
			os_name VARCHAR(191) NOT NULL DEFAULT '',
			arch VARCHAR(64) NOT NULL DEFAULT '',
			kernel VARCHAR(191) NOT NULL DEFAULT '',
			uptime_seconds BIGINT NOT NULL DEFAULT 0,
			boot_time DATETIME(3) NULL,
			updated_at DATETIME(3) NOT NULL,
			PRIMARY KEY (host)
		) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4`,
	}

	for _, stmt := range stmts {
		if _, err := s.db.ExecContext(ctx, stmt); err != nil {
			return fmt.Errorf("%s: %w", firstLine(stmt), err)
		}
	}
	return nil
}

func firstLine(s string) string {
	for i := 0; i < len(s); i++ {
		if s[i] == '\n' {
			return s[:i]
		}
	}
	return s
}
