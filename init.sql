CREATE DATABASE IF NOT EXISTS neurogrid_db;
USE neurogrid_db;

CREATE TABLE IF NOT EXISTS telemetry_records (
    id INT AUTO_INCREMENT PRIMARY KEY,
    subject_id VARCHAR(64) NOT NULL,
    neural_variance DECIMAL(10,4) NOT NULL,
    latency_ms DECIMAL(10,4) NOT NULL,
    stability_score DECIMAL(10,4) NOT NULL,
    status VARCHAR(32) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS access_logs (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id VARCHAR(64) NOT NULL,
    action VARCHAR(128) NOT NULL,
    ip_address VARCHAR(45),
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);