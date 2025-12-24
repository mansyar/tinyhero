-- Sprint 4 Migration: Progress & Rewards
-- Run this in the Supabase SQL Editor

ALTER TABLE sessions 
ADD COLUMN duration_seconds INTEGER DEFAULT 120;

-- Optional: Update existing records to have a default value
UPDATE sessions SET duration_seconds = 120 WHERE duration_seconds IS NULL;
