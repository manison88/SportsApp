-- Already applied to the witness-analytics D1 database. Kept here so the table can be rebuilt.
CREATE TABLE IF NOT EXISTS events (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  ts INTEGER NOT NULL,          -- milliseconds since 1970
  day TEXT NOT NULL,            -- UTC date, YYYY-MM-DD
  name TEXT NOT NULL,
  device TEXT NOT NULL,         -- random id made on the phone; not linked to a person
  session TEXT,
  app_version TEXT,
  os TEXT,
  country TEXT,                 -- from Cloudflare, country only
  props TEXT                    -- JSON: short strings, numbers and booleans only
);
CREATE INDEX IF NOT EXISTS idx_events_name_day ON events (name, day);
CREATE INDEX IF NOT EXISTS idx_events_device_ts ON events (device, ts);
