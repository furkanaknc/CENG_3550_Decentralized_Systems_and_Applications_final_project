import { Pool, PoolConfig, QueryResultRow } from "pg";

function buildPoolConfig(): PoolConfig {
  if (process.env.DATABASE_URL) {
    let connectionString = process.env.DATABASE_URL;

    if (connectionString.includes("${")) {
      connectionString = connectionString.replace(
        /\$\{([^}]+)\}/g,
        (_, name) => {
          return process.env[name] ?? "";
        }
      );
    }
    try {
      new URL(connectionString);
      return { connectionString };
    } catch (err) {
      console.warn(
        "DATABASE_URL is present but invalid or templated; falling back to individual POSTGRES_* environment variables"
      );
    }
  }

  const {
    POSTGRES_HOST = "localhost",
    POSTGRES_PORT = "5428",
    POSTGRES_USER = "recycle_user",
    POSTGRES_PASSWORD = "recycle_pass",
    POSTGRES_DB = "recycle",
  } = process.env;

  return {
    host: POSTGRES_HOST,
    port: Number.parseInt(POSTGRES_PORT, 10),
    user: POSTGRES_USER,
    password: POSTGRES_PASSWORD,
    database: POSTGRES_DB,
  };
}

export const pool = new Pool(buildPoolConfig());

export async function query<T extends QueryResultRow = QueryResultRow>(
  text: string,
  params?: unknown[]
) {
  return pool.query<T>(text, params);
}

export async function shutdownPool(): Promise<void> {
  await pool.end();
}
