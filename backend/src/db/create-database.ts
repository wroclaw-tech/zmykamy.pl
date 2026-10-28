import { SQL } from "bun";
import { env } from "../lib/env";

const databaseUrl = new URL(env.DATABASE_URL);
const databaseName = databaseUrl.pathname.slice(1);
databaseUrl.pathname = "/postgres";

const sql = new SQL(databaseUrl.toString());
const [existing] = await sql`select 1 from pg_database where datname = ${databaseName}`;
if (!existing) {
  await sql.unsafe(`create database "${databaseName}"`);
}
await sql.close();
