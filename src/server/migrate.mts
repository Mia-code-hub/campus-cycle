import Database from 'better-sqlite3';
import { mkdirSync, readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';

const root = process.cwd();
const dbPath = resolve(root, process.env.DATABASE_PATH ?? './data/campus.db');
mkdirSync(dirname(dbPath), { recursive: true });

const schema = readFileSync(resolve(root, 'src/server/schema.sql'), 'utf8');

const db = new Database(dbPath);
db.pragma('journal_mode = WAL');
db.exec(schema);

const rows = db
  .prepare(
    "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name",
  )
  .all() as { name: string }[];
const indexes = db
  .prepare("SELECT name FROM sqlite_master WHERE type='index' AND name LIKE 'idx_%' ORDER BY name")
  .all() as { name: string }[];
db.close();

console.log(`[migrate] 数据库 ${dbPath}`);
console.log(`[migrate] ${rows.length} 张表：${rows.map((r) => r.name).join(', ')}`);
console.log(`[migrate] ${indexes.length} 个索引：${indexes.map((r) => r.name).join(', ')}`);
