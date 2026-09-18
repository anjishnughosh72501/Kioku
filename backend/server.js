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

  // Universal short invite links (/i/:code and /invite/:code)
  app.get(['/i/:code', '/invite/:code'], (req, res, next) => {
    try {
      const code = req.params.code;
      const result = friendsRoutes.resolveInviteDetails(code);

      // If client requests JSON or not explicitly requesting text/html
      const acceptsHtml = req.headers['accept'] && req.headers['accept'].includes('text/html');
      if (!acceptsHtml || req.query.format === 'json') {
        if (result.status === 'invalid') {
          return res.status(404).json(result);
        }
        return res.json(result);
      }

      // Responsive HTML landing page for browser / web fallback
      const inviterName = result.username || 'A friend';
      const friendCode = result.friendCode || '';
      const isValid = result.status === 'valid';
      const appDeepLink = `kioku://i/${encodeURIComponent(code)}`;
      const webApkDownload = 'https://github.com/anjishnughosh72501/Kioku/releases/latest';

      const html = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Kioku — Connect with ${inviterName}</title>
  <link rel="icon" type="image/png" href="/assets/kiokulogo.jpg">
  <style>
    :root {
      --bg: #F7F5F0;
      --card-bg: #FFFFFF;
      --ink: #2C2623;
      --muted: #7D7571;
      --primary: #C87D55;
      --primary-dark: #A5603A;
      --border: #E8E2D9;
    }
    body {
      margin: 0;
      padding: 24px;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
      background: var(--bg);
      color: var(--ink);
      display: flex;
      align-items: center;
      justify-content: center;
      min-height: 100vh;
      box-sizing: border-box;
    }
    .card {
      background: var(--card-bg);
      max-width: 440px;
      width: 100%;
      padding: 36px 28px;
      border-radius: 28px;
      box-shadow: 0 12px 36px rgba(44, 38, 35, 0.08);
      border: 1px solid var(--border);
      text-align: center;
      box-sizing: border-box;
    }
    .logo {
      width: 68px;
      height: 68px;
      border-radius: 20px;
      background: #F0E8DC;
      display: inline-flex;
      align-items: center;
      justify-content: center;
      font-size: 34px;
      margin-bottom: 20px;
      box-shadow: inset 0 2px 4px rgba(255,255,255,0.8), 0 4px 12px rgba(200,125,85,0.2);
    }
    h1 {
      margin: 0 0 10px;
      font-size: 24px;
      font-weight: 700;
      letter-spacing: -0.5px;
    }
    p {
      color: var(--muted);
      font-size: 15px;
      line-height: 1.5;
      margin: 0 0 24px;
    }
    .code-badge {
      display: inline-block;
      background: #F8F4EE;
      border: 1px dashed var(--primary);
      color: var(--primary-dark);
      padding: 6px 16px;
      border-radius: 12px;
      font-weight: 700;
      letter-spacing: 1.5px;
      font-size: 14px;
      margin-bottom: 24px;
    }
    .btn {
      display: block;
      width: 100%;
      padding: 14px 20px;
      border-radius: 16px;
      font-size: 16px;
      font-weight: 600;
      text-decoration: none;
      box-sizing: border-box;
      transition: transform 0.15s ease, background 0.15s ease;
      cursor: pointer;
    }
    .btn-primary {
      background: var(--primary);
      color: #FFF;
      box-shadow: 0 6px 18px rgba(200, 125, 85, 0.35);
      margin-bottom: 12px;
    }
    .btn-primary:hover {
      background: var(--primary-dark);
      transform: translateY(-1px);
    }
    .btn-secondary {
      background: transparent;
      color: var(--ink);
      border: 1px solid var(--border);
    }
    .btn-secondary:hover {
      background: #FAF8F5;
    }
    .footer-text {
      margin-top: 24px;
      font-size: 12px;
      color: var(--muted);
    }
  </style>
</head>
<body>
  <div class="card">
    <div class="logo">🌿</div>
    ${isValid ? `
      <h1>Connect with ${inviterName}</h1>
      <p>${inviterName} wants to share private, end-to-end encrypted memories with you on Kioku.</p>
      <div class="code-badge">INVITE: ${code}</div>
      <a href="${appDeepLink}" class="btn btn-primary">Open in Kioku</a>
      <a href="${webApkDownload}" class="btn btn-secondary">Download Kioku App (Android)</a>
      <script>
        // Attempt deep link launch on mobile
        window.location = "${appDeepLink}";
      </script>
    ` : `
      <h1>Invite Unavailable</h1>
      <p>This invite link is either expired, already used, or invalid.</p>
      <a href="${webApkDownload}" class="btn btn-primary">Get Kioku</a>
    `}
    <div class="footer-text">Kioku • Zero-Knowledge Encrypted Memory Sharing</div>
  </div>
</body>
</html>`;

      res.type('html').send(html);
    } catch (err) {
      next(err);
    }
  });

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