-- Create additional databases
CREATE DATABASE keycloak_db;
CREATE DATABASE research_test_db;

-- Create users
CREATE USER keycloak WITH ENCRYPTED PASSWORD 'keycloak_password';
CREATE USER research_app WITH ENCRYPTED PASSWORD 'research_app_password';

-- Grant privileges
GRANT ALL PRIVILEGES ON DATABASE keycloak_db TO keycloak;
GRANT ALL PRIVILEGES ON DATABASE research_db TO research_app;
GRANT ALL PRIVILEGES ON DATABASE research_test_db TO research_app;

-- Connect to research_db to set up extensions
\c research_db;

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "timescaledb";

-- Create schemas
CREATE SCHEMA IF NOT EXISTS research;
CREATE SCHEMA IF NOT EXISTS audit;

-- Set search path
ALTER DATABASE research_db SET search_path TO research, public;

-- Grant schema permissions
GRANT ALL ON SCHEMA research TO research_app;
GRANT ALL ON SCHEMA audit TO research_app;