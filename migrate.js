const pool = require("./db");

async function migrate() {
  let conn;
  try {
    console.log("Connecting to db for migration...");
    conn = await pool.getConnection();

    await conn.query(`
            CREATE TABLE IF NOT EXISTS items (
                id INT AUTO_INCREMENT PRIMARY KEY,
                name VARCHAR(255) NOT NULL,
                quantity INT NOT NULL DEFAULT 0,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );
        `);
    console.log("Migration successful.");
  } catch (err) {
    console.error("Migration error:", err);
    process.exit(1);
  } finally {
    if (conn) conn.release();
    await pool.end();
  }
}

migrate();
