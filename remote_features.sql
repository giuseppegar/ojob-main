-- Add remote features to database schema
-- Table for managing job requests from remote apps

-- Create job_requests table for remote communication
CREATE TABLE IF NOT EXISTS job_requests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    article_code VARCHAR(100) NOT NULL,
    lot VARCHAR(100) NOT NULL,
    pieces INTEGER NOT NULL CHECK (pieces > 0),
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'completed', 'failed')),
    requested_by VARCHAR(100), -- Optional: to track who made the request
    requested_at TIMESTAMPTZ DEFAULT NOW(),
    processed_at TIMESTAMPTZ,
    error_message TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes for job_requests
CREATE INDEX idx_job_requests_status ON job_requests(status);
CREATE INDEX idx_job_requests_requested_at ON job_requests(requested_at DESC);
CREATE INDEX idx_job_requests_created_at ON job_requests(created_at DESC);

-- Create trigger for updated_at
CREATE TRIGGER update_job_requests_updated_at
    BEFORE UPDATE ON job_requests
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- RLS policies for job_requests
ALTER TABLE job_requests ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Enable all operations for authenticated users" ON job_requests
    FOR ALL USING (true);

CREATE POLICY "Enable all operations for anonymous users" ON job_requests
    FOR ALL USING (true);

-- Insert a test job request
INSERT INTO job_requests (article_code, lot, pieces, requested_by)
VALUES ('TEST-001', 'LOT123', 10, 'Remote App Test');

\echo 'job_requests table created successfully!'
\echo 'Table supports: pending, processing, completed, failed status'
\echo 'Remote apps can insert requests, server app processes them'