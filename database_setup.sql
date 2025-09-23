-- Database setup script for OJob Application
-- PostgreSQL + Supabase compatible schema

-- Drop existing tables if they exist (in correct order due to foreign keys)
DROP TABLE IF EXISTS reject_details CASCADE;
DROP TABLE IF EXISTS quality_monitoring CASCADE;
DROP TABLE IF EXISTS job_schedules CASCADE;

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. JOB_SCHEDULES Table
-- Stores job schedule information and file generation history
CREATE TABLE job_schedules (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    article_code VARCHAR(100) NOT NULL,
    lot VARCHAR(100) NOT NULL,
    pieces INTEGER NOT NULL CHECK (pieces > 0),
    file_path TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. QUALITY_MONITORING Table
-- Main table for quality monitoring data
CREATE TABLE quality_monitoring (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    monitoring_path TEXT NOT NULL,
    total_pieces INTEGER NOT NULL CHECK (total_pieces >= 0),
    good_pieces INTEGER NOT NULL CHECK (good_pieces >= 0),
    rejected_pieces INTEGER NOT NULL CHECK (rejected_pieces >= 0),
    timestamp TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    -- Check constraint to ensure pieces consistency
    CONSTRAINT check_pieces_consistency CHECK (good_pieces + rejected_pieces = total_pieces)
);

-- 3. REJECT_DETAILS Table
-- Detailed information about rejected pieces
CREATE TABLE reject_details (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    quality_monitoring_id UUID NOT NULL REFERENCES quality_monitoring(id) ON DELETE CASCADE,
    station VARCHAR(100) NOT NULL,
    reason TEXT,
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    timestamp TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes for better performance
CREATE INDEX idx_job_schedules_created_at ON job_schedules(created_at DESC);
CREATE INDEX idx_job_schedules_article_code ON job_schedules(article_code);
CREATE INDEX idx_job_schedules_lot ON job_schedules(lot);

CREATE INDEX idx_quality_monitoring_timestamp ON quality_monitoring(timestamp DESC);
CREATE INDEX idx_quality_monitoring_created_at ON quality_monitoring(created_at DESC);
CREATE INDEX idx_quality_monitoring_monitoring_path ON quality_monitoring(monitoring_path);

CREATE INDEX idx_reject_details_quality_id ON reject_details(quality_monitoring_id);
CREATE INDEX idx_reject_details_station ON reject_details(station);
CREATE INDEX idx_reject_details_timestamp ON reject_details(timestamp DESC);

-- Create triggers for updated_at timestamps
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_job_schedules_updated_at
    BEFORE UPDATE ON job_schedules
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_quality_monitoring_updated_at
    BEFORE UPDATE ON quality_monitoring
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_reject_details_updated_at
    BEFORE UPDATE ON reject_details
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Row Level Security (RLS) policies for Supabase
ALTER TABLE job_schedules ENABLE ROW LEVEL SECURITY;
ALTER TABLE quality_monitoring ENABLE ROW LEVEL SECURITY;
ALTER TABLE reject_details ENABLE ROW LEVEL SECURITY;

-- Allow all operations for authenticated users (adjust as needed)
CREATE POLICY "Enable all operations for authenticated users" ON job_schedules
    FOR ALL USING (true);

CREATE POLICY "Enable all operations for authenticated users" ON quality_monitoring
    FOR ALL USING (true);

CREATE POLICY "Enable all operations for authenticated users" ON reject_details
    FOR ALL USING (true);

-- Allow all operations for anonymous users (for development, adjust for production)
CREATE POLICY "Enable all operations for anonymous users" ON job_schedules
    FOR ALL USING (true);

CREATE POLICY "Enable all operations for anonymous users" ON quality_monitoring
    FOR ALL USING (true);

CREATE POLICY "Enable all operations for anonymous users" ON reject_details
    FOR ALL USING (true);

-- Insert some sample data for testing
INSERT INTO job_schedules (article_code, lot, pieces, file_path) VALUES
('PXO7471-250905', '310', 15, '/path/to/job_schedule.txt'),
('ABC123-240801', '205', 25, '/path/to/another_schedule.txt');

INSERT INTO quality_monitoring (monitoring_path, total_pieces, good_pieces, rejected_pieces) VALUES
('/monitoring/path1', 100, 85, 15),
('/monitoring/path2', 50, 48, 2);

-- Get the IDs for reject details insertion
INSERT INTO reject_details (quality_monitoring_id, station, reason, quantity)
SELECT
    qm.id,
    'Station A',
    'Difetto superficie',
    10
FROM quality_monitoring qm
WHERE qm.monitoring_path = '/monitoring/path1'
UNION ALL
SELECT
    qm.id,
    'Station B',
    'Dimensioni fuori tolleranza',
    5
FROM quality_monitoring qm
WHERE qm.monitoring_path = '/monitoring/path1'
UNION ALL
SELECT
    qm.id,
    'Station C',
    'Materiale danneggiato',
    2
FROM quality_monitoring qm
WHERE qm.monitoring_path = '/monitoring/path2';

-- Show table information
\echo 'Database setup completed!'
\echo 'Tables created:'
\echo '- job_schedules: stores job information and file generation history'
\echo '- quality_monitoring: main quality monitoring records'
\echo '- reject_details: detailed reject information linked to quality monitoring'
\echo ''
\echo 'Sample data inserted for testing.'
\echo 'You can now run the Flutter app with: flutter run'