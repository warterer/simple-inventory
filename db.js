const mariadb = require("mariadb");
const minimist = require("minimist");

const args = minimist(process.argv.slice(2), {
  default: {
    db_host: "127.0.0.1",
    db_user: "app",
    db_pass: "12345678",
    db_name: "inventory_db",
  },
});

const pool = mariadb.createPool({
  host: args.db_host,
  user: args.db_user,
  password: args.db_pass,
  database: args.db_name,
  connectionLimit: 5,
});

module.exports = pool;
