const pool = require("../db");

function sendResponse(req, res, data, htmlGenerator) {
  if (req.accepts("html", "json") === "html") {
    res.type("text/html").send(htmlGenerator(data));
  } else {
    res.json(data);
  }
}

class InventoryController {
  async getItems(req, res) {
    let conn;
    try {
      conn = await pool.getConnection();
      const rows = await conn.query("SELECT id, name FROM items");
      sendResponse(
        req,
        res,
        rows,
        (data) => `
                <h1>Inventory</h1>
                <table border="1">
                    <tr><th>ID</th><th>Name</th><th>Action</th></tr>
                    ${data.map((item) => `<tr><td>${item.id}</td><td>${item.name}</td><td><a href="/items/${item.id}">Деталі</a></td></tr>`).join("")}
                </table>
                <br>
                <h3>Додати новий предмет</h3>
                <form action="/items" method="POST">
                    Назва: <input type="text" name="name" required><br>
                    Кількість: <input type="number" name="quantity" required><br>
                    <button type="submit">Додати</button>
                </form>
            `,
      );
    } catch (err) {
      res.status(500).send(err.message);
    } finally {
      if (conn) conn.release();
    }
  }

  async getItemById(req, res) {
    let conn;
    try {
      conn = await pool.getConnection();
      const rows = await conn.query(
        "SELECT id, name, quantity, created_at FROM items WHERE id = ?",
        [req.params.id],
      );
      if (rows.length === 0) return res.status(404).send("Item not found");

      sendResponse(
        req,
        res,
        rows[0],
        (item) => `
                <h1>Item Details: ${item.name}</h1>
                <table border="1">
                    <tr><th>ID</th><td>${item.id}</td></tr>
                    <tr><th>Name</th><td>${item.name}</td></tr>
                    <tr><th>Quantity</th><td>${item.quantity}</td></tr>
                    <tr><th>Created At</th><td>${item.created_at}</td></tr>
                </table>
                <br><a href="/items">Повернутися до списку</a>
            `,
      );
    } catch (err) {
      res.status(500).send(err.message);
    } finally {
      if (conn) conn.release();
    }
  }

  async createItem(req, res) {
    const { name, quantity } = req.body;
    if (!name || !quantity)
      return res.status(400).send("Name and quantity are required");

    let conn;
    try {
      conn = await pool.getConnection();
      const result = await conn.query(
        "INSERT INTO items (name, quantity) VALUES (?, ?)",
        [name, quantity],
      );

      if (req.accepts("html", "json") === "html") {
        res.redirect("/items");
      } else {
        res.status(201).json({ id: Number(result.insertId), name, quantity });
      }
    } catch (err) {
      res.status(500).send(err.message);
    } finally {
      if (conn) conn.release();
    }
  }
}

module.exports = new InventoryController();
