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

-- What fans send from You → Feedback & requests. The Worker creates this table itself on first use.
CREATE TABLE IF NOT EXISTS feedback (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  ts INTEGER NOT NULL,          -- milliseconds since 1970
  kind TEXT NOT NULL,           -- feature | feedback | sport | problem
  text TEXT NOT NULL,           -- the fan's words, up to 2000 characters
  contact TEXT,                 -- how to reach them, if they said
  device TEXT NOT NULL,         -- the same random id as events
  app_version TEXT,
  os TEXT,
  country TEXT,
  done INTEGER NOT NULL DEFAULT 0
);
