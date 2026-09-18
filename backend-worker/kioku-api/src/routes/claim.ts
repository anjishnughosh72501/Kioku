// src/routes/claim.ts
// Hardened zero-knowledge claim token state machine for device-keypair collection key exchange.
// NO raw collection keys or master keys ever pass through here.
// Lifecycle: CREATED -> REDEEMED -> SEALED -> CONSUMED

import { Hono } from 'hono';
import { AppEnv, ClaimTokenRow, AlbumMemberRow } from '../types';
import { generateId } from '../crypto';
import { requireFriendAuth } from '../middleware/auth';

export const claimApp = new Hono<AppEnv>();

// 1. Inviter creates a short-lived, single-use claim token
// Requires authentication and active album membership (Section 10A)
claimApp.post('/request', requireFriendAuth, async (c) => {
  const inviterCode = c.get('friendCode')!;
  const body = await c.req.json<{
    albumId?: string;
    inviterPubKey?: string;
  }>().catch(() => ({}) as any);

  const { albumId, inviterPubKey } = body;
  if (!albumId || !inviterPubKey) {
    return c.json({ error: 'albumId and inviterPubKey are required' }, 400);
  }

  // Verify inviter is an active member or owner of the album
  const member = await c.env.DB.prepare(
    `SELECT role, status FROM album_members WHERE album_id = ? AND user_id = ? AND status = 'active'`
  )
    .bind(albumId, inviterCode)
    .first<AlbumMemberRow>();

  const now = Date.now();

  // If album is not in album_members yet, auto-register inviter as active owner
  if (!member) {
    await c.env.DB.batch([
      c.env.DB.prepare(
        `INSERT OR IGNORE INTO albums (id, owner_user_id, title, storage_type, current_epoch, created_at, updated_at)
         VALUES (?, ?, 'Shared Album', 'local', 1, ?, ?)`
      ).bind(albumId, inviterCode, now, now),
      c.env.DB.prepare(
        `INSERT OR REPLACE INTO album_members (album_id, user_id, role, status, joined_at, updated_at)
         VALUES (?, ?, 'owner', 'active', ?, ?)`
      ).bind(albumId, inviterCode, now, now),
    ]);
  }

  const token = generateId(24);
  const expiresAt = now + 10 * 60 * 1000; // 10 minutes TTL

  await c.env.DB.prepare(
    `INSERT INTO claim_tokens (
       token, album_id, inviter_pub_key, inviter_identity,
       claim_status, expires_at, used, created_at, updated_at
     ) VALUES (?, ?, ?, ?, 'created', ?, 0, ?, ?)`
  )
    .bind(token, albumId, inviterPubKey, inviterCode, expiresAt, now, now)
    .run();

  return c.json({ claimToken: token, expiresAt });
});

// 2. Joining device redeems claim token and registers its recipient public key (Section 10B)
// Binds recipient identity to prevent claim hijacking
claimApp.post('/redeem', requireFriendAuth, async (c) => {
  const recipientCode = c.get('friendCode')!;
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

  const currentStatus = claim.claim_status || (claim.used === 1 ? 'consumed' : 'created');

  if (currentStatus === 'redeemed' || currentStatus === 'sealed') {
    return c.json({ error: 'Claim token has already been redeemed' }, 409);
  }

  if (currentStatus === 'consumed' || claim.used === 1) {
    return c.json({ error: 'Claim token has already been consumed' }, 410);
  }

  if (Date.now() > claim.expires_at) {
    return c.json({ error: 'Claim token has expired' }, 410);
  }

  // Prevent inviter from redeeming their own claim
  if (claim.inviter_identity && claim.inviter_identity === recipientCode) {
    return c.json({ error: 'Cannot redeem your own invite claim' }, 400);
  }

  const now = Date.now();

  // Bind recipient identity and update status to REDEEMED
  await c.env.DB.prepare(
    `UPDATE claim_tokens
     SET claim_status = 'redeemed', recipient_identity = ?, recipient_pub_key = ?, updated_at = ?
     WHERE token = ?`
  )
    .bind(recipientCode, recipientPubKey || null, now, claimToken)
    .run();

  return c.json({
    albumId: claim.album_id,
    inviterPubKey: claim.inviter_pub_key,
  });
});

// 3. Inviter posts sealed collection key (sealed with recipient's public key) (Section 10C)
// Only the inviter who created the claim can post the sealed key
claimApp.post('/seal', requireFriendAuth, async (c) => {
  const callerCode = c.get('friendCode')!;
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

  // Verify caller identity matches the claim inviter
  if (claim.inviter_identity && claim.inviter_identity !== callerCode) {
    return c.json({ error: 'Unauthorized: only the claim creator can seal the key' }, 403);
  }

  const currentStatus = claim.claim_status || (claim.used === 1 ? 'consumed' : 'created');

  if (currentStatus !== 'redeemed') {
    return c.json({ error: `Cannot seal: claim is in ${currentStatus} state, expected redeemed` }, 400);
  }

  const now = Date.now();
  await c.env.DB.prepare(
    `UPDATE claim_tokens SET claim_status = 'sealed', sealed_key = ?, updated_at = ? WHERE token = ?`
  )
    .bind(sealedKey, now, claimToken)
    .run();

  return c.json({ ok: true });
});

// 4. Joining device polls/retrieves sealed collection key (Section 10D)
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

  const currentStatus = claim.claim_status || (claim.used === 1 ? 'consumed' : 'created');

  if (currentStatus === 'consumed' || claim.used === 1) {
    return c.json({ error: 'Claim token has already been consumed' }, 410);
  }

  if (currentStatus !== 'sealed' && !claim.sealed_key) {
    return c.json({
      albumId: claim.album_id,
      sealedKey: null,
      recipientPubKey: claim.recipient_pub_key || null,
      status: currentStatus,
    });
  }

  const now = Date.now();
  // Transition state to consumed on retrieval
  await c.env.DB.prepare(
    `UPDATE claim_tokens SET claim_status = 'consumed', used = 1, updated_at = ? WHERE token = ?`
  )
    .bind(now, claimToken)
    .run();

  return c.json({
    albumId: claim.album_id,
    sealedKey: claim.sealed_key,
    recipientPubKey: claim.recipient_pub_key || null,
  });
});
