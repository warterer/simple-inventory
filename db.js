const mariadb = require("mariadb");
const minimist = require("minimist");

const args = minimist(process.argv.slice(2), {
  default: {
    db_host: process.env.DB_HOST || "127.0.0.1",
    db_user: process.env.DB_USER || "app",
    db_pass: process.env.DB_PASS || "changeme",
    db_name: process.env.DB_NAME || "inventory_db",
  },
});

const pool = mariadb.createPool({
  host: args.db_host,
  user: args.db_user,
  password: String(args.db_pass),
  database: args.db_name,
  connectionLimit: 5,
  connectTimeout: 10000,
});

module.exports = pool;