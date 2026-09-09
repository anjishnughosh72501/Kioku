// server.js
require('dotenv').config();
const crypto = require('crypto');
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const { initDB } = require('./db');
const { notFoundHandler, jsonErrorHandler } = require('./middleware/errorHandler');

// If no JWT secret is configured, generate an ephemeral one so the app still
// works out of the box. Tokens will stop validating after a restart, so a
// real secret in .env is strongly recommended.
function resolveJwtSecret() {
  const stored = process.env.JWT_SECRET;
  if (!stored || stored === 'change-me-to-a-random-secret') {
    process.env.JWT_SECRET = crypto.randomBytes(32).toString('hex');
    console.warn(
      'WARN: JWT_SECRET not set in .env - using an ephemeral secret. ' +
        'Tokens will invalidate on restart; set JWT_SECRET to keep sessions stable.'
    );
  }
}

function createApp() {
  const authRoutes = require('./routes/auth');
  const mediaRoutes = require('./routes/media');
  const flashbackRoutes = require('./routes/flashbacks');

  const app = express();
  app.disable('x-powered-by');
  // One proxy hop ahead of the app when served through cloudflared/a tunnel.
  app.set('trust proxy', 1);
  app.use(helmet());

  // Mobile clients don't send Origin headers, so CORS only matters for
  // browser-based testing. Restrict via CORS_ORIGINS (comma-separated) or
  // default to reflecting any origin.
  const corsOrigins = process.env.CORS_ORIGINS
    ? process.env.CORS_ORIGINS.split(',').map((s) => s.trim())
    : true;
  app.use(cors({ origin: corsOrigins }));

  app.use(express.json({ limit: '1mb' }));

  app.get('/health', (req, res) => res.json({ ok: true }));

  app.use('/auth', authRoutes);
  app.use('/media', mediaRoutes);
  app.use('/flashbacks', flashbackRoutes);

  app.use(notFoundHandler);
  app.use(jsonErrorHandler);

  return app;
}

async function main() {
  resolveJwtSecret();
  await initDB();
  console.log('Database initialized');

  const { startFlashbackScheduler } = require('./flashbackJob');
  const app = createApp();

  const PORT = process.env.PORT || 4000;
  app.listen(PORT, '0.0.0.0', () => {
    console.log(`Kioku backend running on http://localhost:${PORT}`);
    startFlashbackScheduler();
  });
}

if (require.main === module) {
  main().catch((err) => {
    console.error('Failed to start server:', err);
    process.exit(1);
  });
}

module.exports = { createApp, resolveJwtSecret };