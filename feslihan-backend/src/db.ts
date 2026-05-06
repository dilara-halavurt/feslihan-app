import { drizzle } from "drizzle-orm/node-postgres";
import pg from "pg";
import * as schema from "./schema.js";

const pool = new pg.Pool({
  connectionString: "postgresql://localhost/feslihan",
});

export const db = drizzle(pool, { schema });
