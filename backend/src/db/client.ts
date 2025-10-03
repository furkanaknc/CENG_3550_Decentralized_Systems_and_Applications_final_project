import { Pool, PoolConfig, QueryResultRow } from 'pg';

function buildPoolConfig(): PoolConfig {
  if (process.env.DATABASE_URL) {
    return { connectionString: process.env.DATABASE_URL };
  }

  const {
    POSTGRES_HOST = 'localhost',
    POSTGRES_PORT = '5432',
    POSTGRES_USER = 'postgres',
    POSTGRES_PASSWORD = 'postgres',
    POSTGRES_DB = 'postgres'
  } = process.env;

  return {
    host: POSTGRES_HOST,
    port: Number.parseInt(POSTGRES_PORT, 10),
    user: POSTGRES_USER,
    password: POSTGRES_PASSWORD,
    database: POSTGRES_DB
  };
}

export const pool = new Pool(buildPoolConfig());

export async function query<T extends QueryResultRow = QueryResultRow>(text: string, params?: unknown[]) {
  return pool.query<T>(text, params);
}

export async function shutdownPool(): Promise<void> {
  await pool.end();
}
