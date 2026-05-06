-- ============================================================
-- Build My Protocol Wizard: additional JSONB columns
-- Adds health_goals and condition_entries to user_intake_sessions
-- so the wizard can persist all step data to the database.
-- ============================================================

-- Health goals with priority ordering from Step 1
-- Format: [{id, category, label, priority}]
ALTER TABLE user_intake_sessions
  ADD COLUMN IF NOT EXISTS health_goals JSONB DEFAULT '[]'::jsonb;

-- Condition entries (diagnosed/suspected) from Step 2
-- Format: [{name, status: "diagnosed"|"suspected"}]
ALTER TABLE user_intake_sessions
  ADD COLUMN IF NOT EXISTS condition_entries JSONB DEFAULT '[]'::jsonb;

-- Track which wizard step the user is on (for session resume)
ALTER TABLE user_intake_sessions
  ADD COLUMN IF NOT EXISTS wizard_step INTEGER DEFAULT 0;

-- Source of intake: 'chatbot' (legacy) or 'wizard' (Build My Protocol)
ALTER TABLE user_intake_sessions
  ADD COLUMN IF NOT EXISTS intake_source TEXT DEFAULT 'chatbot';
