const express = require("express");
const minimist = require("minimist");
const path = require("path");
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
  if (req.accepts("html", "json") === "html") {
    res.sendFile(path.join(__dirname, "views", "index.html"));
  } else {
    res.status(406).send("text/html only");
  }
});

app.listen(args.port, () => {
  console.log(`App is running on port ${args.port}`);
});
