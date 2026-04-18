const express = require("express");
const minimist = require("minimist");
const pool = require("./db");
const inventoryRoutes = require("./routes/inventory.routes");

const args = minimist(process.argv.slice(2), {
  default: { port: 8080 },
});

const app = express();
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

app.use("/", inventoryRoutes);

app.get("/health/alive", (req, res) => {
  res.status(200).send("OK");
});

app.get("/health/ready", async (req, res) => {
  let conn;
  try {
    conn = await pool.getConnection();
    await conn.query("SELECT 1");
    res.status(200).send("OK");
  } catch (err) {
    res.status(500).send(`Database connection failed: ${err.message}`);
  } finally {
    if (conn) conn.release();
  }
});

app.get("/", (req, res) => {
  res.type("text/html").send(`
        <h1>Simple Inventory API</h1>
        <ul>
            <li><a href="/items">GET /items</a> - Список усіх предметів</li>
            <li>POST /items (name, quantity) - Створити запис</li>
            <li>GET /items/&lt;id&gt; - Деталі предмету</li>
            <li><a href="/health/alive">GET /health/alive</a></li>
            <li><a href="/health/ready">GET /health/ready</a></li>
        </ul>
    `);
});

app.listen(args.port, () => {
  console.log(`App is running on port ${args.port}`);
});
