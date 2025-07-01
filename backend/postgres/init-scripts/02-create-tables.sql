-- Switch to research database
\c research_db;

-- Set the default schema
SET search_path TO research, public;

-- Enable Row Level Security
ALTER DATABASE research_db SET row_security = on;

-- Research Projects Table
CREATE TABLE IF NOT EXISTS research_projects (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    status VARCHAR(50) DEFAULT 'active' CHECK (status IN ('active', 'completed', 'paused', 'archived')),
    start_date DATE,
    end_date DATE,
    ethics_approval_number VARCHAR(100),
    config JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    CONSTRAINT valid_dates CHECK (end_date IS NULL OR end_date >= start_date)
);

-- Researchers Table
CREATE TABLE IF NOT EXISTS researchers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    institution VARCHAR(255),
    department VARCHAR(255),
    orcid VARCHAR(20),
    role VARCHAR(50) DEFAULT 'researcher' CHECK (role IN ('admin', 'pi', 'researcher', 'assistant')),
    is_active BOOLEAN DEFAULT true,
    last_login TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Project Members (Many-to-Many)
CREATE TABLE IF NOT EXISTS project_members (
    project_id UUID REFERENCES research_projects(id) ON DELETE CASCADE,
    researcher_id UUID REFERENCES researchers(id) ON DELETE CASCADE,
    role VARCHAR(50) DEFAULT 'member' CHECK (role IN ('lead', 'member', 'viewer')),
    permissions JSONB DEFAULT '{"can_edit": false, "can_export": true, "can_delete": false}',
    joined_at TIMESTAMPTZ DEFAULT NOW(),
    left_at TIMESTAMPTZ,
    PRIMARY KEY (project_id, researcher_id)
);

-- Participants Table (with encryption support)
CREATE TABLE IF NOT EXISTS participants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id UUID REFERENCES research_projects(id) ON DELETE CASCADE,
    participant_code VARCHAR(100) NOT NULL,
    encrypted_demographics BYTEA, -- Encrypted JSON data
    demographics_hash VARCHAR(64), -- For searching without decryption
    consent_status VARCHAR(50) DEFAULT 'pending' CHECK (consent_status IN ('pending', 'obtained', 'withdrawn', 'expired')),
    consent_date TIMESTAMPTZ,
    consent_expiry_date TIMESTAMPTZ,
    withdrawal_date TIMESTAMPTZ,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(project_id, participant_code)
);

-- Experiment Protocols Table
CREATE TABLE IF NOT EXISTS experiment_protocols (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id UUID REFERENCES research_projects(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    version VARCHAR(50) DEFAULT '1.0.0',
    description TEXT,
    protocol_data JSONB NOT NULL,
    required_sensors JSONB DEFAULT '[]',
    duration_minutes INTEGER,
    is_active BOOLEAN DEFAULT true,
    is_template BOOLEAN DEFAULT false,
    created_by UUID REFERENCES researchers(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(project_id, name, version)
);

-- Sensor Devices Table
CREATE TABLE IF NOT EXISTS sensor_devices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id VARCHAR(255) UNIQUE NOT NULL,
    device_type VARCHAR(100) NOT NULL,
    device_name VARCHAR(255),
    manufacturer VARCHAR(255),
    model VARCHAR(255),
    firmware_version VARCHAR(50),
    capabilities JSONB DEFAULT '{}',
    calibration_data JSONB DEFAULT '{}',
    last_calibration_date TIMESTAMPTZ,
    is_active BOOLEAN DEFAULT true,
    registered_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Experiment Sessions Table
CREATE TABLE IF NOT EXISTS experiment_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id UUID REFERENCES research_projects(id) ON DELETE CASCADE,
    participant_id UUID REFERENCES participants(id) ON DELETE CASCADE,
    protocol_id UUID REFERENCES experiment_protocols(id),
    session_code VARCHAR(100) NOT NULL,
    scheduled_time TIMESTAMPTZ,
    start_time TIMESTAMPTZ,
    end_time TIMESTAMPTZ,
    status VARCHAR(50) DEFAULT 'scheduled' CHECK (status IN ('scheduled', 'in_progress', 'completed', 'cancelled', 'failed')),
    environment_data JSONB DEFAULT '{}', -- Temperature, humidity, etc.
    metadata JSONB DEFAULT '{}',
    notes TEXT,
    quality_score FLOAT CHECK (quality_score >= 0 AND quality_score <= 1),
    created_by UUID REFERENCES researchers(id),
    conducted_by UUID REFERENCES researchers(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Session Devices (Many-to-Many)
CREATE TABLE IF NOT EXISTS session_devices (
    session_id UUID REFERENCES experiment_sessions(id) ON DELETE CASCADE,
    device_id UUID REFERENCES sensor_devices(id),
    attachment_location VARCHAR(255), -- e.g., "left_wrist", "chest"
    configuration JSONB DEFAULT '{}',
    PRIMARY KEY (session_id, device_id)
);

-- Data Files Table
CREATE TABLE IF NOT EXISTS data_files (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID REFERENCES experiment_sessions(id) ON DELETE CASCADE,
    file_type VARCHAR(50) NOT NULL CHECK (file_type IN ('raw', 'processed', 'export', 'report', 'other')),
    file_format VARCHAR(50) NOT NULL,
    file_path VARCHAR(500) NOT NULL,
    file_size_bytes BIGINT,
    checksum VARCHAR(255),
    compression_type VARCHAR(50),
    metadata JSONB DEFAULT '{}',
    is_encrypted BOOLEAN DEFAULT false,
    uploaded_at TIMESTAMPTZ DEFAULT NOW(),
    uploaded_by UUID REFERENCES researchers(id)
);

-- Time Series Sensor Data Table (for TimescaleDB)
CREATE TABLE IF NOT EXISTS sensor_data (
    time TIMESTAMPTZ NOT NULL,
    session_id UUID NOT NULL,
    device_id VARCHAR(255) NOT NULL,
    sensor_type VARCHAR(50) NOT NULL,
    channel VARCHAR(50), -- e.g., 'x', 'y', 'z' for accelerometer
    value DOUBLE PRECISION NOT NULL,
    unit VARCHAR(50),
    quality_flag INTEGER DEFAULT 0, -- 0=good, 1=questionable, 2=bad
    PRIMARY KEY (time, session_id, device_id, sensor_type, channel)
);

-- Convert to TimescaleDB hypertable
SELECT create_hypertable('sensor_data', 'time', 
    chunk_time_interval => INTERVAL '1 day',
    if_not_exists => TRUE);

-- Create compression policy (compress chunks older than 7 days)
SELECT add_compression_policy('sensor_data', INTERVAL '7 days', if_not_exists => TRUE);

-- Aggregated Sensor Data (1-minute aggregates)
CREATE TABLE IF NOT EXISTS sensor_data_1min (
    time TIMESTAMPTZ NOT NULL,
    session_id UUID NOT NULL,
    device_id VARCHAR(255) NOT NULL,
    sensor_type VARCHAR(50) NOT NULL,
    channel VARCHAR(50),
    min_value DOUBLE PRECISION,
    max_value DOUBLE PRECISION,
    avg_value DOUBLE PRECISION,
    std_dev DOUBLE PRECISION,
    sample_count INTEGER,
    PRIMARY KEY (time, session_id, device_id, sensor_type, channel)
);

-- Convert to hypertable
SELECT create_hypertable('sensor_data_1min', 'time',
    chunk_time_interval => INTERVAL '7 days',
    if_not_exists => TRUE);

-- Event Markers Table
CREATE TABLE IF NOT EXISTS event_markers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID REFERENCES experiment_sessions(id) ON DELETE CASCADE,
    timestamp TIMESTAMPTZ NOT NULL,
    event_type VARCHAR(100) NOT NULL,
    event_data JSONB DEFAULT '{}',
    source VARCHAR(50), -- 'manual', 'automatic', 'protocol'
    created_by UUID REFERENCES researchers(id),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Processing Jobs Table
CREATE TABLE IF NOT EXISTS processing_jobs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID REFERENCES experiment_sessions(id) ON DELETE CASCADE,
    job_type VARCHAR(100) NOT NULL,
    priority INTEGER DEFAULT 5 CHECK (priority >= 1 AND priority <= 10),
    status VARCHAR(50) DEFAULT 'pending' CHECK (status IN ('pending', 'queued', 'running', 'completed', 'failed', 'cancelled')),
    parameters JSONB DEFAULT '{}',
    result JSONB,
    error_message TEXT,
    progress FLOAT DEFAULT 0 CHECK (progress >= 0 AND progress <= 100),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    queued_at TIMESTAMPTZ,
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    created_by UUID REFERENCES researchers(id)
);

-- Analysis Results Table
CREATE TABLE IF NOT EXISTS analysis_results (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID REFERENCES experiment_sessions(id) ON DELETE CASCADE,
    analysis_type VARCHAR(100) NOT NULL,
    version VARCHAR(50) DEFAULT '1.0.0',
    parameters JSONB DEFAULT '{}',
    results JSONB NOT NULL,
    quality_metrics JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID REFERENCES researchers(id)
);

-- Audit Log Table
CREATE TABLE IF NOT EXISTS audit.audit_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    timestamp TIMESTAMPTZ DEFAULT NOW(),
    user_id UUID,
    action VARCHAR(100) NOT NULL,
    resource_type VARCHAR(100),
    resource_id UUID,
    changes JSONB,
    ip_address INET,
    user_agent TEXT,
    success BOOLEAN DEFAULT true,
    error_message TEXT
);

-- Create indexes for better performance
CREATE INDEX idx_projects_status ON research_projects(status) WHERE status = 'active';
CREATE INDEX idx_projects_dates ON research_projects(start_date, end_date);

CREATE INDEX idx_participants_project ON participants(project_id);
CREATE INDEX idx_participants_consent ON participants(consent_status);
CREATE INDEX idx_participants_hash ON participants(demographics_hash);

CREATE INDEX idx_sessions_project ON experiment_sessions(project_id);
CREATE INDEX idx_sessions_participant ON experiment_sessions(participant_id);
CREATE INDEX idx_sessions_status ON experiment_sessions(status);
CREATE INDEX idx_sessions_time ON experiment_sessions(start_time, end_time);

CREATE INDEX idx_sensor_data_session ON sensor_data(session_id);
CREATE INDEX idx_sensor_data_device ON sensor_data(device_id);
CREATE INDEX idx_sensor_data_type ON sensor_data(sensor_type);

CREATE INDEX idx_events_session ON event_markers(session_id);
CREATE INDEX idx_events_time ON event_markers(timestamp);
CREATE INDEX idx_events_type ON event_markers(event_type);

CREATE INDEX idx_jobs_session ON processing_jobs(session_id);
CREATE INDEX idx_jobs_status ON processing_jobs(status);
CREATE INDEX idx_jobs_type ON processing_jobs(job_type);

CREATE INDEX idx_audit_user ON audit.audit_log(user_id);
CREATE INDEX idx_audit_resource ON audit.audit_log(resource_type, resource_id);
CREATE INDEX idx_audit_timestamp ON audit.audit_log(timestamp);

-- Create update timestamp trigger function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Apply update trigger to relevant tables
CREATE TRIGGER update_research_projects_updated_at BEFORE UPDATE ON research_projects
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_researchers_updated_at BEFORE UPDATE ON researchers
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_participants_updated_at BEFORE UPDATE ON participants
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_protocols_updated_at BEFORE UPDATE ON experiment_protocols
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_devices_updated_at BEFORE UPDATE ON sensor_devices
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_sessions_updated_at BEFORE UPDATE ON experiment_sessions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Create continuous aggregate for sensor data
CREATE MATERIALIZED VIEW sensor_data_hourly_stats
WITH (timescaledb.continuous) AS
SELECT
    time_bucket('1 hour', time) AS hour,
    session_id,
    device_id,
    sensor_type,
    channel,
    MIN(value) as min_value,
    MAX(value) as max_value,
    AVG(value) as avg_value,
    STDDEV(value) as std_dev,
    COUNT(*) as sample_count
FROM sensor_data
GROUP BY hour, session_id, device_id, sensor_type, channel
WITH NO DATA;

-- Create refresh policy for continuous aggregate
SELECT add_continuous_aggregate_policy('sensor_data_hourly_stats',
    start_offset => INTERVAL '3 hours',
    end_offset => INTERVAL '1 hour',
    schedule_interval => INTERVAL '1 hour',
    if_not_exists => TRUE);