-- Fix: Add all role names expected by application code
-- The roles table UNIQUE constraint on 'name' means we need distinct names
-- for each role that verifyDbRole() checks

INSERT INTO roles (name, description) VALUES
  ('np', 'Nurse Practitioner'),
  ('pa', 'Physician Assistant'),
  ('pharmacist', 'Licensed Pharmacist'),
  ('admin_support', 'Support administrator'),
  ('admin_manager', 'Manager administrator'),
  ('admin_super', 'Super administrator with full access')
ON CONFLICT (name) DO NOTHING;
