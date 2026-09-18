// server.js
require('dotenv').config();
const crypto = require('crypto');
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const { initDB } = require('./db');
const { notFoundHandler, jsonErrorHandler } = require('./middleware/errorHandler');

// Fail closed if no secure JWT secret is configured in production or regular runs.
function resolveJwtSecret() {
  const stored = process.env.JWT_SECRET;
  if (!stored || stored === 'change-me-to-a-random-secret') {
    if (process.env.NODE_ENV === 'production' || process.env.NODE_ENV !== 'test') {
      throw new Error(
        'FATAL: JWT_SECRET must be set to a cryptographically secure random value in .env. Server will fail closed.'
      );
    }
  }
}

function createApp() {
  const claimRoutes = require('./routes/claim');
  const flashbackRoutes = require('./routes/flashbacks');
  const friendsRoutes = require('./routes/friends');

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

  // Public compliance & policy endpoints for app stores and web verification (P0-4)
  const fs = require('fs');
  const path = require('path');
  app.get('/privacy', (req, res) => {
    const privacyPath = path.resolve(__dirname, '../PRIVACY_POLICY.md');
    if (fs.existsSync(privacyPath)) {
      res.type('text/markdown').send(fs.readFileSync(privacyPath, 'utf8'));
    } else {
      res.type('text/plain').send('Kioku Zero-Knowledge Privacy Policy: Your photos and videos are end-to-end encrypted on device.');
    }
  });

  app.get('/terms', (req, res) => {
    const termsPath = path.resolve(__dirname, '../TERMS_OF_SERVICE.md');
    if (fs.existsSync(termsPath)) {
      res.type('text/markdown').send(fs.readFileSync(termsPath, 'utf8'));
    } else {
      res.type('text/plain').send('Kioku Terms of Service: Decentralized, local-first encrypted photo album.');
    }
  });

  app.use('/claim', claimRoutes);
  app.use('/flashbacks', flashbackRoutes);
  app.use('/friends', friendsRoutes);

  // Deprecated legacy demo mode: Plaintext Google Drive routes.
  // Gated behind LEGACY_DEMO_MODE=true or test environment.
  // Never reachable or enabled in shipped E2EE zero-knowledge release builds.
  // P1-7: Refuse to boot if LEGACY_DEMO_MODE=true in production.
  if (process.env.LEGACY_DEMO_MODE === 'true') {
    if (process.env.NODE_ENV === 'production') {
      throw new Error('FATAL: LEGACY_DEMO_MODE cannot be enabled in production. Refusing to start.');
    }
  }

  if (process.env.LEGACY_DEMO_MODE === 'true' || process.env.NODE_ENV === 'test') {
    const authRoutes = require('./routes/auth');
    const mediaRoutes = require('./routes/media');
    app.use('/auth', authRoutes);
    app.use('/media', mediaRoutes);
  }

  app.use(notFoundHandler);
  app.use(jsonErrorHandler);

  return app;
}

async function main() {
  resolveJwtSecret();
  await initDB();
  console.log('Database initialized');

  const http = require('http');
  const { setupSignaling } = require('./services/signalService');
  const { startFlashbackScheduler } = require('./flashbackJob');
  const app = createApp();
  const server = http.createServer(app);
  setupSignaling(server);

  const PORT = process.env.PORT || 4000;
  server.listen(PORT, '0.0.0.0', () => {
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