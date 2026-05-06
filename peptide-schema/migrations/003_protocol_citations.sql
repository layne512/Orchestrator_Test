-- Migration 003: Add citation + combinations columns to peptide_protocols
ALTER TABLE peptide_protocols
  ADD COLUMN IF NOT EXISTS source_citations TEXT[] DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS combinations     TEXT[] DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS category         TEXT;   -- "GH/Muscle" | "Metabolic" | "Recovery" | etc.
