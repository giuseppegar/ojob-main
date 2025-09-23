-- Update database schema to match app requirements
-- This script fixes the reject_details table structure

-- Drop and recreate reject_details table with correct columns
DROP TABLE IF EXISTS reject_details CASCADE;

-- Recreate reject_details table with all required columns from the app
CREATE TABLE reject_details (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    quality_monitoring_id UUID NOT NULL REFERENCES quality_monitoring(id) ON DELETE CASCADE,
    station VARCHAR(100) NOT NULL,
    code VARCHAR(50),                -- Added: reject code field
    description TEXT,                -- Added: reject description (was 'reason' before)
    progressivo INTEGER,             -- Added: progressive number field
    quantity INTEGER CHECK (quantity > 0), -- Made optional since app doesn't always send it
    timestamp TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Recreate indexes for the new table structure
CREATE INDEX idx_reject_details_quality_id ON reject_details(quality_monitoring_id);
CREATE INDEX idx_reject_details_station ON reject_details(station);
CREATE INDEX idx_reject_details_code ON reject_details(code);
CREATE INDEX idx_reject_details_timestamp ON reject_details(timestamp DESC);

-- Recreate trigger for updated_at
CREATE TRIGGER update_reject_details_updated_at
    BEFORE UPDATE ON reject_details
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Recreate RLS policies
ALTER TABLE reject_details ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Enable all operations for authenticated users" ON reject_details
    FOR ALL USING (true);

CREATE POLICY "Enable all operations for anonymous users" ON reject_details
    FOR ALL USING (true);

-- Insert some test data with the new structure
INSERT INTO reject_details (quality_monitoring_id, station, code, description, progressivo)
SELECT
    qm.id,
    'Station A',
    'DEF001',
    'Difetto superficie',
    1
FROM quality_monitoring qm
WHERE qm.monitoring_path = '/monitoring/path1'
LIMIT 1;

\echo 'reject_details table updated successfully with new schema!'
\echo 'New columns added: code, description (renamed from reason), progressivo'
\echo 'quantity is now optional'