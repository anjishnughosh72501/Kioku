// src/routes/claim.ts
// Short-lived single-use claim tokens for secure device-keypair collection key exchange.
// NO raw collection keys or master keys ever pass through here.

import { Hono } from 'hono';
import { AppEnv, ClaimTokenRow } from '../types';
import { generateId } from '../crypto';

export const claimApp = new Hono<AppEnv>();

// 1. Inviter creates a short-lived, single-use claim token
claimApp.post('/request', async (c) => {
  const body = await c.req.json<{
    albumId?: string;
    inviterPubKey?: string;
  }>().catch(() => ({}) as any);

  const { albumId, inviterPubKey } = body;
  if (!albumId || !inviterPubKey) {
    return c.json({ error: 'albumId and inviterPubKey are required' }, 400);
  }

  const token = generateId(24);
  const expiresAt = Date.now() + 10 * 60 * 1000; // 10 minutes TTL

  await c.env.DB.prepare(
    `INSERT INTO claim_tokens (token, album_id, inviter_pub_key, expires_at, used)
     VALUES (?, ?, ?, ?, 0)`
  )
    .bind(token, albumId, inviterPubKey, expiresAt)
    .run();

  return c.json({ claimToken: token, expiresAt });
});

// 2. Joining device redeems claim token and registers its recipient public key
claimApp.post('/redeem', async (c) => {
  const body = await c.req.json<{
    claimToken?: string;
    recipientPubKey?: string;
  }>().catch(() => ({}) as any);

  const { claimToken, recipientPubKey } = body;
  if (!claimToken) {
    return c.json({ error: 'claimToken is required' }, 400);
  }

  const claim = await c.env.DB.prepare(`SELECT * FROM claim_tokens WHERE token = ?`)
    .bind(claimToken)
    .first<ClaimTokenRow>();

  if (!claim) {
    return c.json({ error: 'Claim token not found' }, 404);
  }

  if (claim.used === 1) {
    return c.json({ error: 'Claim token has already been used' }, 410);
  }

  if (Date.now() > claim.expires_at) {
    return c.json({ error: 'Claim token has expired' }, 410);
  }

  // Mark as used
  await c.env.DB.prepare(
    `UPDATE claim_tokens SET used = 1, recipient_pub_key = ? WHERE token = ?`
  )
    .bind(recipientPubKey || null, claimToken)
    .run();

  return c.json({
    albumId: claim.album_id,
    inviterPubKey: claim.inviter_pub_key,
  });
});

// 3. Inviter posts sealed collection key (sealed with recipient's public key)
claimApp.post('/seal', async (c) => {
  const body = await c.req.json<{
    claimToken?: string;
    sealedKey?: string;
  }>().catch(() => ({}) as any);

  const { claimToken, sealedKey } = body;
  if (!claimToken || !sealedKey) {
    return c.json({ error: 'claimToken and sealedKey are required' }, 400);
  }

  const claim = await c.env.DB.prepare(`SELECT * FROM claim_tokens WHERE token = ?`)
    .bind(claimToken)
    .first<ClaimTokenRow>();

  if (!claim) {
    return c.json({ error: 'Claim token not found' }, 404);
  }

  await c.env.DB.prepare(`UPDATE claim_tokens SET sealed_key = ? WHERE token = ?`)
    .bind(sealedKey, claimToken)
    .run();

  return c.json({ ok: true });
});

// 4. Joining device polls/retrieves sealed collection key
claimApp.get('/sealed/:claimToken', async (c) => {
  const claimToken = c.req.param('claimToken');
  const claim = await c.env.DB.prepare(`SELECT * FROM claim_tokens WHERE token = ?`)
    .bind(claimToken)
    .first<ClaimTokenRow>();

  if (!claim) {
    return c.json({ error: 'Claim token not found' }, 404);
  }

  if (Date.now() > claim.expires_at + 60 * 60 * 1000) {
    return c.json({ error: 'Claim record expired' }, 410);
  }

  return c.json({
    albumId: claim.album_id,
    sealedKey: claim.sealed_key || null,
    recipientPubKey: claim.recipient_pub_key || null,
  });
});
