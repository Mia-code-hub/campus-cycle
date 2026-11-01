import Database from 'better-sqlite3';
import { existsSync, mkdirSync } from 'node:fs';
import { dirname, resolve } from 'node:path';

// turbopackIgnore: SQLite 文件在运行时按需打开，避免静态分析把整个项目跟踪进产物
const DB_PATH = resolve(/*turbopackIgnore: true*/ process.cwd(), process.env.DATABASE_PATH ?? './data/campus.db');

const dir = dirname(DB_PATH);
if (!existsSync(dir)) mkdirSync(dir, { recursive: true });

declare global {
  // Next.js 开发模式热重载会重复求值模块，用 globalThis 缓存避免连接泄漏
  var __campusDb: Database.Database | undefined;
}

export function getDb(): Database.Database {
  if (globalThis.__campusDb) return globalThis.__campusDb;
  const db = new Database(DB_PATH);
  db.pragma('journal_mode = WAL');
  db.pragma('foreign_keys = ON');
  globalThis.__campusDb = db;
  return db;
}

export default getDb;
