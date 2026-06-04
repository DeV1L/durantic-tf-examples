"use strict";

// Durantic demo frontend.
// Serves the static UI and reverse-proxies /api/* to the backend (over the Durantic mesh,
// via the backend VIP). This is the only tier with a user-facing public IP.
//
// Config (env, written at boot by the Durantic role into /etc/durantic/frontend.env):
//   BACKEND_URL  base URL of the backend, e.g. http://10.61.0.100:3000
//   PORT         listen port (default 80)

const path = require("path");
const express = require("express");
const { createProxyMiddleware } = require("http-proxy-middleware");

const PORT = parseInt(process.env.PORT || "80", 10);
const BACKEND_URL = process.env.BACKEND_URL || "http://127.0.0.1:3000";

const app = express();

// Forward API calls to the backend. /api/generate, /api/documents, /api/documents/:id
// Mounted at the app root with a pathFilter so the /api prefix is preserved on the way out.
app.use(
  createProxyMiddleware({
    pathFilter: "/api",
    target: BACKEND_URL,
    changeOrigin: true,
  })
);

app.use(express.static(path.join(__dirname, "public")));

app.listen(PORT, "0.0.0.0", () => {
  console.log(`frontend listening on :${PORT}, proxying /api -> ${BACKEND_URL}`);
});
