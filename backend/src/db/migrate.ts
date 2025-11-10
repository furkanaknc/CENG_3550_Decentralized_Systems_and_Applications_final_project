import fs from 'fs/promises';
import path from 'path';
import { pool } from './client';

const MIGRATIONS_DIR = path.resolve(__dirname, '../../db/migrations');

async function ensureMigrationsTable(): Promise<void> {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS schema_migrations (
      id SERIAL PRIMARY KEY,
      filename TEXT UNIQUE NOT NULL,
      applied_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
    )
  `);
}

async function hasMigrationRun(filename: string): Promise<boolean> {
  const result = await pool.query('SELECT 1 FROM schema_migrations WHERE filename = $1', [filename]);
  return (result.rowCount ?? 0) > 0;
}

async function recordMigration(filename: string): Promise<void> {
  await pool.query('INSERT INTO schema_migrations (filename) VALUES ($1)', [filename]);
}

export async function runMigrations(): Promise<void> {
  await ensureMigrationsTable();

  const files = await fs.readdir(MIGRATIONS_DIR);
  const sqlFiles = files.filter((file) => file.endsWith('.sql')).sort();

  for (const file of sqlFiles) {
    const alreadyApplied = await hasMigrationRun(file);
    if (alreadyApplied) {
      continue;
    }

    const migrationPath = path.join(MIGRATIONS_DIR, file);
    const sql = await fs.readFile(migrationPath, 'utf-8');

    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      await client.query(sql);
      await recordMigration(file);
      await client.query('COMMIT');
    } catch (error) {
      await client.query('ROLLBACK');
      console.error(`Failed to run migration ${file}`);
      throw error;
    } finally {
      client.release();
    }
  }
}

if (require.main === module) {
  runMigrations()
    .then(() => {
      console.log('All migrations applied');
      return pool.end();
    })
    .catch((error) => {
      console.error('Migration failed', error);
      process.exitCode = 1;
    });
}
