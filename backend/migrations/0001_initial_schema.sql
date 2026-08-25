CREATE TABLE users (
  id TEXT PRIMARY KEY,
  nickname TEXT NOT NULL CHECK (length(nickname) BETWEEN 1 AND 30),
  avatar TEXT NOT NULL CHECK (length(avatar) BETWEEN 1 AND 100),
  link_code TEXT NOT NULL UNIQUE CHECK (length(link_code) = 11),
  token_hash TEXT NOT NULL UNIQUE CHECK (length(token_hash) = 64),
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE TABLE links (
  user_a_id TEXT NOT NULL,
  user_b_id TEXT NOT NULL,
  created_at TEXT NOT NULL,
  PRIMARY KEY (user_a_id, user_b_id),
  FOREIGN KEY (user_a_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (user_b_id) REFERENCES users(id) ON DELETE CASCADE,
  CHECK (user_a_id < user_b_id)
);

CREATE INDEX links_by_user_b ON links(user_b_id, user_a_id);

CREATE TABLE checkins (
  user_id TEXT NOT NULL,
  prayer_date TEXT NOT NULL CHECK (
    prayer_date GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]'
  ),
  prayer TEXT NOT NULL CHECK (prayer IN ('fajr', 'dhuhr', 'asr', 'maghrib', 'isha')),
  completed_at TEXT NOT NULL,
  PRIMARY KEY (user_id, prayer_date, prayer),
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX checkins_by_date_and_prayer
  ON checkins(prayer_date, prayer, user_id);
