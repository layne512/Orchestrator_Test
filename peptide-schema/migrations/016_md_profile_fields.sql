-- MD Profile Fields Migration
-- Adds bio, profile photo, consultation pricing, and availability preferences

ALTER TABLE md_credentials
  ADD COLUMN IF NOT EXISTS bio                    TEXT,
  ADD COLUMN IF NOT EXISTS profile_photo_url      TEXT,
  ADD COLUMN IF NOT EXISTS specialties            TEXT[] DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS states_licensed        TEXT[] DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS price_async_cents      INTEGER,             -- async consultation price in cents
  ADD COLUMN IF NOT EXISTS price_video_cents      INTEGER,             -- video consultation price in cents
  ADD COLUMN IF NOT EXISTS availability_notes     TEXT,                -- free-text availability preferences
  ADD COLUMN IF NOT EXISTS accepts_new_patients   BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS profile_complete       BOOLEAN DEFAULT false;
