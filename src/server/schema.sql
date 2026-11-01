-- 校园闲置物资循环 AI 平台 · SQLite 表结构
-- 唯一事实来源：docs/03-数据库设计.md。改字段先改文档，再改本文件。

CREATE TABLE IF NOT EXISTS users (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  username        TEXT    NOT NULL UNIQUE,
  password_hash   TEXT    NOT NULL,
  salt            TEXT    NOT NULL,
  nickname        TEXT    NOT NULL,
  college         TEXT,
  grade           TEXT,
  role            TEXT    NOT NULL DEFAULT 'user' CHECK (role IN ('user','admin')),
  is_aid_approved INTEGER NOT NULL DEFAULT 0 CHECK (is_aid_approved IN (0,1,2,3)),
  created_at      TEXT    NOT NULL DEFAULT (datetime('now','localtime'))
);

CREATE TABLE IF NOT EXISTS items (
  id               INTEGER PRIMARY KEY AUTOINCREMENT,
  owner_id         INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title            TEXT    NOT NULL,
  raw_desc         TEXT,
  ai_desc          TEXT,
  category         TEXT    NOT NULL CHECK (category IN
                     ('textbook','bedding','stationery','appliance','daily','clothing','other')),
  condition_level  TEXT    CHECK (condition_level IN ('95新','9成新','8成新','可用')),
  mode             TEXT    NOT NULL CHECK (mode IN ('sale','donate')),
  price            REAL    NOT NULL DEFAULT 0,
  ai_price_low     REAL,
  ai_price_high    REAL,
  ai_tags          TEXT,
  ai_edited        INTEGER NOT NULL DEFAULT 0 CHECK (ai_edited IN (0,1,2)),
  image_path       TEXT,
  donate_tag       TEXT,
  status           TEXT    NOT NULL DEFAULT 'listed' CHECK (status IN
                     ('listed','reserved','completed','removed')),
  violation_flag   INTEGER NOT NULL DEFAULT 0 CHECK (violation_flag IN (0,1,2)),
  violation_reason TEXT,
  embedding        BLOB,
  embedded_at      TEXT,
  view_count       INTEGER NOT NULL DEFAULT 0,
  created_at       TEXT    NOT NULL DEFAULT (datetime('now','localtime'))
);
CREATE INDEX IF NOT EXISTS idx_items_category ON items(category, mode);
CREATE INDEX IF NOT EXISTS idx_items_owner    ON items(owner_id);
CREATE INDEX IF NOT EXISTS idx_items_status   ON items(status);

CREATE TABLE IF NOT EXISTS favorites (
  user_id    INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  item_id    INTEGER NOT NULL REFERENCES items(id) ON DELETE CASCADE,
  created_at TEXT    NOT NULL DEFAULT (datetime('now','localtime')),
  PRIMARY KEY (user_id, item_id)
);

CREATE TABLE IF NOT EXISTS applications (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  item_id      INTEGER NOT NULL REFERENCES items(id) ON DELETE CASCADE,
  applicant_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  reason       TEXT,
  status       TEXT    NOT NULL DEFAULT 'pending' CHECK (status IN
                 ('pending','approved','rejected','completed','cancelled')),
  created_at   TEXT    NOT NULL DEFAULT (datetime('now','localtime')),
  updated_at   TEXT    NOT NULL DEFAULT (datetime('now','localtime'))
);
CREATE INDEX IF NOT EXISTS idx_app_item ON applications(item_id, status);

CREATE TABLE IF NOT EXISTS donations (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  application_id  INTEGER REFERENCES applications(id) ON DELETE SET NULL,
  item_id         INTEGER NOT NULL REFERENCES items(id) ON DELETE CASCADE,
  donor_id        INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  receiver_id     INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  green_weight_kg REAL    NOT NULL DEFAULT 0,
  donated_at      TEXT    NOT NULL DEFAULT (datetime('now','localtime'))
);
CREATE INDEX IF NOT EXISTS idx_donations_donor ON donations(donor_id);

CREATE TABLE IF NOT EXISTS letters (
  id                  INTEGER PRIMARY KEY AUTOINCREMENT,
  donation_id         INTEGER NOT NULL UNIQUE REFERENCES donations(id) ON DELETE CASCADE,
  content             TEXT    NOT NULL,
  receiver_anonymous  INTEGER NOT NULL DEFAULT 1,
  issued_at           TEXT    NOT NULL DEFAULT (datetime('now','localtime'))
);

CREATE TABLE IF NOT EXISTS messages (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  item_id      INTEGER NOT NULL REFERENCES items(id) ON DELETE CASCADE,
  from_user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  to_user_id   INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  content      TEXT    NOT NULL,
  read_flag    INTEGER NOT NULL DEFAULT 0,
  created_at   TEXT    NOT NULL DEFAULT (datetime('now','localtime'))
);
CREATE INDEX IF NOT EXISTS idx_msg_pair ON messages(item_id, from_user_id, to_user_id);

CREATE TABLE IF NOT EXISTS aid_applications (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id      INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  reason       TEXT    NOT NULL,
  proof_note   TEXT,
  status       TEXT    NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','approved','rejected')),
  reviewed_by  INTEGER REFERENCES users(id) ON DELETE SET NULL,
  created_at   TEXT    NOT NULL DEFAULT (datetime('now','localtime')),
  reviewed_at  TEXT
);

-- AI 调用留痕：比赛要交的「Prompt 历史快照」直接来自这张表
CREATE TABLE IF NOT EXISTS ai_call_logs (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  feature       TEXT    NOT NULL CHECK (feature IN
                  ('analyze','search','moderate','letter','report','embed')),
  model         TEXT    NOT NULL,
  user_id       INTEGER REFERENCES users(id) ON DELETE SET NULL,
  ref_item_id   INTEGER REFERENCES items(id) ON DELETE SET NULL,
  prompt_text   TEXT    NOT NULL,
  response_text TEXT    NOT NULL,
  parsed_result TEXT,
  latency_ms    INTEGER,
  status        TEXT    NOT NULL DEFAULT 'ok' CHECK (status IN
                  ('ok','timeout','parse_error','api_error')),
  created_at    TEXT    NOT NULL DEFAULT (datetime('now','localtime'))
);
CREATE INDEX IF NOT EXISTS idx_ai_logs_feature ON ai_call_logs(feature, created_at);
