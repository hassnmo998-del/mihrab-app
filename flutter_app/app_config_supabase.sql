-- ======================================================
-- ÃœÊ· app_config · Œ“Ì‰ ≈⁄œ«œ«  «· ÿ»Ìﬁ ⁄»— «·”Õ«»
--  ‘€¯· Â–« ›Ì Supabase Dashboard > SQL Editor
-- ======================================================

CREATE TABLE IF NOT EXISTS app_config (
  key   TEXT PRIMARY KEY,
  value TEXT NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

--  ›⁄Ì· RLS (Row Level Security)
ALTER TABLE app_config ENABLE ROW LEVEL SECURITY;

-- ”Ì«”… «·ﬁ—«¡…: „› ÊÕ… ·· ÿ»Ìﬁ (anon key)
CREATE POLICY ""Allow read for all"" ON app_config
  FOR SELECT USING (true);

-- ≈œŒ«· »Ì«‰«  «·”Ê»— √œ„‰ «·«› —«÷Ì…
INSERT INTO app_config (key, value) VALUES
  ('super_admin_email',    'admin@masjed.app'),
  ('super_admin_password', 'super2026')
ON CONFLICT (key) DO NOTHING;

-- ======================================================
-- · €ÌÌ— «·»Ì«‰«  ·«Õﬁ«° ‘€¯· ›Ì SQL Editor:
-- UPDATE app_config SET value = 'newEmail@example.com' WHERE key = 'super_admin_email';
-- UPDATE app_config SET value = 'newPassword123'       WHERE key = 'super_admin_password';
-- ======================================================
