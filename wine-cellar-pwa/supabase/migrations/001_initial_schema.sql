-- Whitelist of approved users
CREATE TABLE approved_emails (
  email TEXT PRIMARY KEY
);
INSERT INTO approved_emails (email) VALUES ('alex.bell25@gmail.com'), ('rwbell719@gmail.com');

-- Cellars
CREATE TABLE cellars (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  owner_name TEXT NOT NULL,
  owner_id UUID NOT NULL REFERENCES auth.users(id),
  last_updated TIMESTAMPTZ DEFAULT now()
);

-- Wines
CREATE TABLE wines (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  cellar_id UUID NOT NULL REFERENCES cellars(id) ON DELETE CASCADE,
  name TEXT DEFAULT '',
  producer TEXT DEFAULT '',
  variety TEXT DEFAULT '',
  region TEXT DEFAULT '',
  country TEXT DEFAULT '',
  vintage INT DEFAULT 0,
  zone TEXT DEFAULT '',
  slot INT DEFAULT 1,
  notes TEXT DEFAULT '',
  date_added TIMESTAMPTZ DEFAULT now(),
  quantity INT DEFAULT 1,
  photo_path TEXT
);

-- Drinking logs
CREATE TABLE drinking_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id),
  wine_name TEXT DEFAULT '',
  producer TEXT DEFAULT '',
  variety TEXT DEFAULT '',
  vintage INT DEFAULT 0,
  date_consumed TIMESTAMPTZ DEFAULT now(),
  rating INT DEFAULT 3 CHECK (rating >= 1 AND rating <= 5),
  tasting_notes TEXT DEFAULT ''
);

-- Indexes
CREATE INDEX idx_wines_cellar_id ON wines(cellar_id);
CREATE INDEX idx_wines_zone ON wines(zone);
CREATE INDEX idx_drinking_logs_user_id ON drinking_logs(user_id);

-- Enable Realtime
ALTER PUBLICATION supabase_realtime ADD TABLE wines, drinking_logs, cellars;

-- RLS
ALTER TABLE cellars ENABLE ROW LEVEL SECURITY;
ALTER TABLE wines ENABLE ROW LEVEL SECURITY;
ALTER TABLE drinking_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "read_all_cellars" ON cellars FOR SELECT
  USING (auth.email() IN (SELECT email FROM approved_emails));

CREATE POLICY "read_all_wines" ON wines FOR SELECT
  USING (auth.email() IN (SELECT email FROM approved_emails));

CREATE POLICY "manage_own_cellars" ON cellars FOR ALL
  USING (owner_id = auth.uid()) WITH CHECK (owner_id = auth.uid());

CREATE POLICY "insert_own_wines" ON wines FOR INSERT
  WITH CHECK (cellar_id IN (SELECT id FROM cellars WHERE owner_id = auth.uid()));

CREATE POLICY "update_own_wines" ON wines FOR UPDATE
  USING (cellar_id IN (SELECT id FROM cellars WHERE owner_id = auth.uid()));

CREATE POLICY "delete_own_wines" ON wines FOR DELETE
  USING (cellar_id IN (SELECT id FROM cellars WHERE owner_id = auth.uid()));

CREATE POLICY "manage_own_logs" ON drinking_logs FOR ALL
  USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

-- Storage bucket (run separately in Supabase dashboard Storage section)
-- Create bucket named "wine-photos" with public access enabled

-- Storage RLS policies (after creating the bucket)
CREATE POLICY "read_wine_photos" ON storage.objects FOR SELECT
  USING (bucket_id = 'wine-photos');

CREATE POLICY "upload_own_photos" ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'wine-photos'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

CREATE POLICY "manage_own_photos" ON storage.objects FOR UPDATE
  USING (bucket_id = 'wine-photos' AND (storage.foldername(name))[1] = auth.uid()::text);

CREATE POLICY "delete_own_photos" ON storage.objects FOR DELETE
  USING (bucket_id = 'wine-photos' AND (storage.foldername(name))[1] = auth.uid()::text);
