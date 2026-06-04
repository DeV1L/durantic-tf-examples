"use strict";

// Durantic demo backend.
// - POST /api/generate  : render the submitted text into a PDF with a random font,
//                         store the PDF bytes in MongoDB, return its metadata.
// - GET  /api/documents : list stored document metadata (newest first).
// - GET  /api/documents/:id : download a stored PDF.
// - GET  /healthz       : liveness (used by the Durantic VIP TCP health check).
//
// Config (env, written at boot by the Durantic role into /etc/durantic/backend.env):
//   MONGODB_URL  mongodb connection string (with credentials)
//   PORT         listen port (default 3000)

const express = require("express");
const PDFDocument = require("pdfkit");
const { MongoClient, ObjectId, Binary } = require("mongodb");

const PORT = parseInt(process.env.PORT || "3000", 10);
const MONGODB_URL = process.env.MONGODB_URL || "mongodb://127.0.0.1:27017";
const DB_NAME = process.env.MONGODB_DB || "durantic_demo";
const MAX_CHARS = 400;

// PDFKit ships these 14 standard fonts — no font files needed.
const FONTS = [
  "Helvetica",
  "Helvetica-Bold",
  "Helvetica-Oblique",
  "Times-Roman",
  "Times-Bold",
  "Times-Italic",
  "Courier",
  "Courier-Bold",
  "Courier-Oblique",
];

const client = new MongoClient(MONGODB_URL);
let documents;

// Render text into a PDF and resolve with a Buffer of the bytes.
function renderPdf(text, font) {
  return new Promise((resolve, reject) => {
    const doc = new PDFDocument({ margin: 50 });
    const chunks = [];
    doc.on("data", (c) => chunks.push(c));
    doc.on("end", () => resolve(Buffer.concat(chunks)));
    doc.on("error", reject);

    doc.font(font).fontSize(24).text("Durantic Demo Document", { align: "center" });
    doc.moveDown();
    doc.font(font).fontSize(12).fillColor("#666").text(`Font: ${font}`, { align: "center" });
    doc.moveDown(2);
    doc.font(font).fontSize(16).fillColor("#000").text(text, { align: "left" });
    doc.end();
  });
}

const app = express();
app.use(express.json({ limit: "64kb" }));

app.get("/healthz", (_req, res) => res.json({ status: "ok" }));

app.post("/api/generate", async (req, res) => {
  const text = (req.body && req.body.text ? String(req.body.text) : "").trim();
  if (!text) {
    return res.status(400).json({ error: "text is required" });
  }
  if (text.length > MAX_CHARS) {
    return res.status(400).json({ error: `text must be at most ${MAX_CHARS} characters` });
  }

  const font = FONTS[Math.floor(Math.random() * FONTS.length)];
  try {
    const pdf = await renderPdf(text, font);
    const createdAt = new Date();
    const filename = `document-${createdAt.toISOString().replace(/[:.]/g, "-")}.pdf`;
    const result = await documents.insertOne({
      filename,
      font,
      createdAt,
      contentType: "application/pdf",
      data: new Binary(pdf),
    });
    res.status(201).json({
      id: result.insertedId.toString(),
      filename,
      font,
      createdAt: createdAt.toISOString(),
    });
  } catch (err) {
    console.error("generate failed:", err);
    res.status(500).json({ error: "failed to generate document" });
  }
});

app.get("/api/documents", async (_req, res) => {
  try {
    const docs = await documents
      .find({}, { projection: { data: 0 } })
      .sort({ createdAt: -1 })
      .toArray();
    res.json(
      docs.map((d) => ({
        id: d._id.toString(),
        filename: d.filename,
        font: d.font,
        createdAt: d.createdAt,
      }))
    );
  } catch (err) {
    console.error("list failed:", err);
    res.status(500).json({ error: "failed to list documents" });
  }
});

app.get("/api/documents/:id", async (req, res) => {
  let id;
  try {
    id = new ObjectId(req.params.id);
  } catch {
    return res.status(400).json({ error: "invalid id" });
  }
  try {
    const doc = await documents.findOne({ _id: id });
    if (!doc) {
      return res.status(404).json({ error: "not found" });
    }
    res.setHeader("Content-Type", doc.contentType || "application/pdf");
    res.setHeader("Content-Disposition", `attachment; filename="${doc.filename}"`);
    res.send(doc.data.buffer ? Buffer.from(doc.data.buffer) : Buffer.from(doc.data));
  } catch (err) {
    console.error("download failed:", err);
    res.status(500).json({ error: "failed to download document" });
  }
});

async function main() {
  await client.connect();
  documents = client.db(DB_NAME).collection("documents");
  await documents.createIndex({ createdAt: -1 });
  app.listen(PORT, "0.0.0.0", () => {
    console.log(`backend listening on :${PORT}, mongo=${MONGODB_URL.replace(/\/\/[^@]*@/, "//***@")}`);
  });
}

main().catch((err) => {
  console.error("fatal:", err);
  process.exit(1);
});
