-- Migration 004: Add type column to peptide_protocols
-- Distinguishes between peptides (injected/intranasal) and supplements (oral)
-- Run in Supabase SQL Editor before seed 004_supplement_protocols.sql

ALTER TABLE peptide_protocols
  ADD COLUMN IF NOT EXISTS type TEXT NOT NULL DEFAULT 'peptide'
  CHECK (type IN ('peptide', 'supplement'));

-- Backfill all existing rows as 'peptide'
UPDATE peptide_protocols SET type = 'peptide' WHERE type IS NULL OR type = 'peptide';

-- Index for filtering by type
CREATE INDEX IF NOT EXISTS idx_peptide_protocols_type ON peptide_protocols(type);
