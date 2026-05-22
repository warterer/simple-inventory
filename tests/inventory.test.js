const request = require("supertest");

jest.mock("../db", () => ({
  getConnection: jest.fn(),
  end: jest.fn().mockResolvedValue(undefined),
}));

const pool = require("../db");
const app = require("../app");

function mockConn(queryResult) {
  const conn = {
    query: jest.fn().mockResolvedValue(queryResult),
    release: jest.fn(),
  };
  pool.getConnection.mockResolvedValue(conn);
  return conn;
}

function mockConnError(message = "DB error") {
  pool.getConnection.mockRejectedValue(new Error(message));
}

describe("GET /health/alive", () => {
  it("returns 200 OK", async () => {
    const res = await request(app).get("/health/alive");
    expect(res.status).toBe(200);
    expect(res.text).toBe("OK");
  });
});

describe("GET /health/ready", () => {
  it("returns 200 when DB is available", async () => {
    mockConn([[{ "1": 1 }]]);
    const res = await request(app).get("/health/ready");
    expect(res.status).toBe(200);
  });

  it("returns 500 when DB is unavailable", async () => {
    mockConnError("connection refused");
    const res = await request(app).get("/health/ready");
    expect(res.status).toBe(500);
    expect(res.text).toContain("connection refused");
  });
});

describe("GET /", () => {
  it("returns HTML when Accept: text/html", async () => {
    const res = await request(app).get("/").set("Accept", "text/html");
    expect(res.status).toBe(200);
    expect(res.type).toMatch(/html/);
  });

  it("returns 406 when Accept: application/json", async () => {
    const res = await request(app).get("/").set("Accept", "application/json");
    expect(res.status).toBe(406);
  });
});

describe("GET /items", () => {
  it("returns JSON array of items", async () => {
    mockConn([
      { id: 1, name: "Pencil" },
      { id: 2, name: "Notebook" },
    ]);
    const res = await request(app)
      .get("/items")
      .set("Accept", "application/json");
    expect(res.status).toBe(200);
    expect(Array.isArray(res.body)).toBe(true);
    expect(res.body[0]).toHaveProperty("name", "Pencil");
  });

  it("returns HTML when Accept: text/html", async () => {
    mockConn([{ id: 1, name: "Pencil" }]);
    const res = await request(app).get("/items").set("Accept", "text/html");
    expect(res.status).toBe(200);
    expect(res.text).toContain("Inventory");
  });

  it("returns 500 when DB fails", async () => {
    mockConnError("query failed");
    const res = await request(app)
      .get("/items")
      .set("Accept", "application/json");
    expect(res.status).toBe(500);
  });
});

describe("GET /items/:id", () => {
  it("returns item by ID", async () => {
    mockConn([{ id: 1, name: "Ruler", quantity: 5, created_at: new Date() }]);
    const res = await request(app)
      .get("/items/1")
      .set("Accept", "application/json");
    expect(res.status).toBe(200);
    expect(res.body).toHaveProperty("name", "Ruler");
  });

  it("returns 404 if item is not found", async () => {
    mockConn([]);
    const res = await request(app)
      .get("/items/999")
      .set("Accept", "application/json");
    expect(res.status).toBe(404);
  });

  it("returns 500 when DB fails", async () => {
    mockConnError("timeout");
    const res = await request(app)
      .get("/items/1")
      .set("Accept", "application/json");
    expect(res.status).toBe(500);
  });
});

describe("POST /items", () => {
  it("creates item and returns 201 with JSON", async () => {
    mockConn({ insertId: 42n });
    const res = await request(app)
      .post("/items")
      .set("Accept", "application/json")
      .send({ name: "Paper", quantity: 100 });
    expect(res.status).toBe(201);
    expect(res.body).toMatchObject({ id: 42, name: "Paper", quantity: 100 });
  });

  it("returns 400 if name is missing", async () => {
    const res = await request(app)
      .post("/items")
      .set("Accept", "application/json")
      .send({ quantity: 5 });
    expect(res.status).toBe(400);
  });

  it("returns 400 if quantity is missing", async () => {
    const res = await request(app)
      .post("/items")
      .set("Accept", "application/json")
      .send({ name: "Something" });
    expect(res.status).toBe(400);
  });

  it("returns 500 when DB fails", async () => {
    mockConnError("insert failed");
    const res = await request(app)
      .post("/items")
      .set("Accept", "application/json")
      .send({ name: "Test", quantity: 1 });
    expect(res.status).toBe(500);
  });
});