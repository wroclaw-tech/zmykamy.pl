import { SQL } from "bun";

const databaseUrl = new URL(process.env.DATABASE_URL!);
const databaseName = databaseUrl.pathname.slice(1);
databaseUrl.pathname = "/postgres";

const sql = new SQL(databaseUrl.toString());
const [existing] = await sql`select 1 from pg_database where datname = ${databaseName}`;
if (!existing) {
  await sql.unsafe(`create database "${databaseName}"`);
}
await sql.close();
