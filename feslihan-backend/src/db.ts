import { drizzle } from "drizzle-orm/node-postgres";
import pg from "pg";
import * as schema from "./schema.js";

const pool = new pg.Pool({
  connectionString: process.env.DATABASE_URL || "postgresql://localhost/feslihan",
  ssl: process.env.DATABASE_URL ? { rejectUnauthorized: false } : false,
});

export const db = drizzle(pool, { schema });
