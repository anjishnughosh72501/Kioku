// src/routes/landing.ts
// Universal short invite links (/i/:code and /invite/:code)
// Serves responsive HTML landing page for web browsers or JSON for API clients.

import { Hono } from 'hono';
import { AppEnv } from '../types';
import { resolveInviteDetails } from './friends';

export const landingApp = new Hono<AppEnv>();

async function handleInviteLanding(c: any, code: string) {
  const result = await resolveInviteDetails(code, c.env.DB);
  const acceptHeader = c.req.header('accept') || '';
  const formatQuery = c.req.query('format');
  const acceptsHtml = acceptHeader.includes('text/html');

  if (!acceptsHtml || formatQuery === 'json') {
    if (result.status === 'invalid') {
      return c.json(result, 404);
    }
    return c.json(result);
  }

  // Responsive HTML landing page for browser / web fallback
  const inviterName = result.username || 'A friend';
  const isValid = result.status === 'valid';
  const appDeepLink = `kioku://i/${encodeURIComponent(code)}`;
  const webApkDownload = 'https://github.com/anjishnughosh72501/Kioku/releases/latest';

  const html = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Kioku — Connect with ${inviterName}</title>
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
    ${
      isValid
        ? `
      <h1>Connect with ${inviterName}</h1>
      <p>${inviterName} wants to share private, end-to-end encrypted memories with you on Kioku.</p>
      <div class="code-badge">INVITE: ${code}</div>
      <a href="${appDeepLink}" class="btn btn-primary">Open in Kioku</a>
      <a href="${webApkDownload}" class="btn btn-secondary">Download Kioku App (Android)</a>
    `
        : `
      <h1>Invite Unavailable</h1>
      <p>This invite link is either expired, already used, or invalid.</p>
      <a href="${webApkDownload}" class="btn btn-primary">Get Kioku</a>
    `
    }
    <div class="footer-text">Kioku • Zero-Knowledge Encrypted Memory Sharing</div>
  </div>
</body>
</html>`;

  return c.html(html);
}

// Android Digital Asset Links verification endpoint
landingApp.get('/.well-known/assetlinks.json', (c) => {
  return c.json([
    {
      relation: ['delegate_permission/common.handle_all_urls'],
      target: {
        namespace: 'android_app',
        package_name: 'com.kioku.app',
        sha256_cert_fingerprints: [
          'E4:A1:26:4E:0A:88:B0:1B:D3:2B:B1:A9:DB:1C:61:B2:61:AA:3A:BD:1F:5D:D9:9E:1E:8E:0B:D3:C8:56:E8:08'
        ]
      }
    }
  ]);
});

// iOS Universal Links verification endpoints
landingApp.get('/.well-known/apple-app-site-association', (c) => {
  return c.json({
    applinks: {
      apps: [],
      details: [
        {
          appID: 'TEAMID.com.kioku.app',
          paths: ['/i/*', '/invite/*', '/albums/*']
        }
      ]
    }
  });
});

landingApp.get('/apple-app-site-association', (c) => {
  return c.json({
    applinks: {
      apps: [],
      details: [
        {
          appID: 'TEAMID.com.kioku.app',
          paths: ['/i/*', '/invite/*', '/albums/*']
        }
      ]
    }
  });
});

landingApp.get('/i/:code', async (c) => {
  return handleInviteLanding(c, c.req.param('code'));
});

landingApp.get('/invite/:code', async (c) => {
  return handleInviteLanding(c, c.req.param('code'));
});
