// src/index.ts
// Kioku Production Cloudflare Worker + D1 Backend

import { Hono } from 'hono';
import { cors } from 'hono/cors';
import { AppEnv, Env } from './types';
import { friendsApp } from './routes/friends';
import { claimApp } from './routes/claim';
import { flashbacksApp, runFlashbackGeneration } from './routes/flashbacks';
import { landingApp } from './routes/landing';
import { signalingApp } from './routes/signaling';
import { legacyAuthApp, legacyMediaApp } from './routes/legacy';

const app = new Hono<AppEnv>();

// CORS configuration matching backend/server.js
app.use('*', async (c, next) => {
  const corsMiddleware = cors({
    origin: (origin) => {
      if (c.env.CORS_ORIGINS) {
        const allowed = c.env.CORS_ORIGINS.split(',').map((s) => s.trim());
        return allowed.includes(origin) ? origin : allowed[0];
      }
      return origin || '*';
    },
    allowMethods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
    allowHeaders: ['Content-Type', 'Authorization'],
  });
  return corsMiddleware(c, next);
});

// Health check endpoint (matches Flutter & start.py expectation)
app.get('/health', (c) => {
  return c.json({ ok: true });
});

// App store and compliance endpoints
app.get('/privacy', (c) => {
  return c.text(
    '# Kioku Privacy Policy\n\nKioku is a zero-knowledge encrypted photo and memory sharing platform. Photos and videos are end-to-end encrypted directly on client devices before replication. The backend server acts strictly as an encrypted metadata relay and authentication cache without access to photo bytes or decryption keys.'
  );
});

app.get('/terms', (c) => {
  return c.text(
    '# Kioku Terms of Service\n\nKioku provides decentralized, local-first encrypted photo sharing for trusted circles. Users maintain sole ownership of their encrypted content.'
  );
});

// Mount application routes
app.route('/friends', friendsApp);
app.route('/claim', claimApp);
app.route('/flashbacks', flashbacksApp);
app.route('/signal', signalingApp);
app.route('/auth', legacyAuthApp);
app.route('/media', legacyMediaApp);
app.route('/', landingApp);

// 404 Handler
app.notFound((c) => {
  return c.json({ error: 'Route not found' }, 404);
});

// Global Error Handler
app.onError((err, c) => {
  console.error('[Worker Error]', err);
  return c.json({ error: err.message || 'Internal Server Error' }, 500);
});

export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    return app.fetch(request, env, ctx);
  },

  async scheduled(controller: ScheduledController, env: Env, ctx: ExecutionContext): Promise<void> {
    ctx.waitUntil(runFlashbackGeneration(env.DB));
  },
};