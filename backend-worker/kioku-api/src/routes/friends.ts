// src/routes/friends.ts
import { Hono } from 'hono';
import {
  AppEnv,
  FriendAccountRow,
  FriendRequestRow,
  InviteRow,
  AlbumInviteRow,
} from '../types';
import { hashSecret, generateInviteCode, generateId, signJwt, getJwtSecret } from '../crypto';
import { requireFriendAuth } from '../middleware/auth';

export const friendsApp = new Hono<AppEnv>();

export async function resolveInviteDetails(rawCode: string, db: D1Database) {
  if (!rawCode) return { status: 'invalid' };
  const cleanCode = String(rawCode).trim().toUpperCase();

  const invite = await db
    .prepare(`SELECT * FROM invites WHERE invite_code = ?`)
    .bind(cleanCode)
    .first<InviteRow>();

  if (!invite) {
    return { status: 'invalid' };
  }

  const now = Date.now();
  if (invite.status === 'valid' && now > invite.expires_at) {
    await db
      .prepare(`UPDATE invites SET status = 'expired' WHERE id = ?`)
      .bind(invite.id)
      .run();
    return { status: 'expired' };
  }

  if (invite.status !== 'valid') {
    return { status: invite.status };
  }

  const account = await db
    .prepare(`SELECT username FROM friend_accounts WHERE friend_code = ?`)
    .bind(invite.created_by)
    .first<{ username: string | null }>();

  return {
    username: account?.username || invite.from_name || 'Friend',
    friendCode: invite.created_by,
    status: 'valid',
    expiresAt: invite.expires_at,
  };
}

// 0. Issue / refresh authorization token for a friend code using device secret
friendsApp.post('/token', async (c) => {
  const body = await c.req.json<{
    friendCode?: string;
    secret?: string;
    username?: string;
  }>().catch(() => ({}) as any);

  const { friendCode, secret, username } = body;
  if (!friendCode || !secret) {
    return c.json({ error: 'friendCode and secret are required' }, 400);
  }

  const cleanCode = String(friendCode).trim().toUpperCase();
  if (cleanCode.length < 3 || cleanCode.length > 32) {
    return c.json({ error: 'friendCode must be between 3 and 32 characters' }, 400);
  }

  const cleanSecret = String(secret).trim();
  if (cleanSecret.length < 16) {
    return c.json({ error: 'secret must be at least 16 characters' }, 400);
  }

  const secretHash = await hashSecret(cleanSecret);
  const existing = await c.env.DB.prepare(
    `SELECT * FROM friend_accounts WHERE friend_code = ?`
  )
    .bind(cleanCode)
    .first<FriendAccountRow>();

  if (!existing) {
    await c.env.DB.prepare(
      `INSERT INTO friend_accounts (friend_code, secret_hash, username, created_at) VALUES (?, ?, ?, ?)`
    )
      .bind(cleanCode, secretHash, username ? String(username).trim() : null, Date.now())
      .run();
  } else {
    if (existing.secret_hash !== secretHash) {
      return c.json({ error: 'Invalid device credentials for this friend code' }, 401);
    }
    if (username) {
      await c.env.DB.prepare(
        `UPDATE friend_accounts SET username = ? WHERE friend_code = ?`
      )
        .bind(String(username).trim(), cleanCode)
        .run();
    }
  }

  const jwtSecret = getJwtSecret(c.env);
  const token = await signJwt(
    { friendCode: cleanCode },
    jwtSecret,
    90 * 24 * 60 * 60 // 90 days
  );

  return c.json({ token, friendCode: cleanCode });
});

// 1. Send friend request
friendsApp.post('/request', requireFriendAuth, async (c) => {
  const body = await c.req.json<{ toCode?: string; fromName?: string }>().catch(() => ({}) as any);
  const { toCode, fromName } = body;
  const fromCode = c.get('friendCode')!;

  if (!toCode) {
    return c.json({ error: 'toCode is required' }, 400);
  }

  const cleanFrom = fromCode;
  const cleanTo = String(toCode).trim().toUpperCase();

  if (cleanFrom === cleanTo) {
    return c.json({ error: 'Cannot send a friend request to yourself' }, 400);
  }

  // Verify recipient account exists (Section 5H)
  const recipient = await c.env.DB.prepare(
    `SELECT friend_code FROM friend_accounts WHERE friend_code = ?`
  )
    .bind(cleanTo)
    .first<{ friend_code: string }>();

  if (!recipient) {
    return c.json({ error: 'Recipient friend code does not exist' }, 404);
  }

  // Check if already friends
  const u1 = cleanFrom < cleanTo ? cleanFrom : cleanTo;
  const u2 = cleanFrom < cleanTo ? cleanTo : cleanFrom;
  const alreadyFriends = await c.env.DB.prepare(
    `SELECT 1 FROM friends WHERE user_a = ? AND user_b = ?`
  )
    .bind(u1, u2)
    .first();

  if (alreadyFriends) {
    return c.json({ error: 'Already connected as friends' }, 409);
  }

  // Check if active pending request already exists from sender
  const existing = await c.env.DB.prepare(
    `SELECT id, status FROM friend_requests WHERE from_code = ? AND to_code = ? AND status = 'pending'`
  )
    .bind(cleanFrom, cleanTo)
    .first<{ id: string; status: string }>();

  if (existing) {
    return c.json({ id: existing.id, status: 'pending', alreadySent: true });
  }

  // Handle reciprocal pending request (Section 5A: Clean reciprocal auto-pairing)
  const reciprocal = await c.env.DB.prepare(
    `SELECT id, from_name FROM friend_requests WHERE from_code = ? AND to_code = ? AND status = 'pending'`
  )
    .bind(cleanTo, cleanFrom)
    .first<{ id: string; from_name: string | null }>();

  const now = Date.now();

  if (reciprocal) {
    // Atomically accept reciprocal request and create friendship
    await c.env.DB.batch([
      c.env.DB.prepare(
        `UPDATE friend_requests SET status = 'accepted', updated_at = ? WHERE id = ?`
      ).bind(now, reciprocal.id),
      c.env.DB.prepare(
        `INSERT OR IGNORE INTO friends (user_a, user_b, created_at) VALUES (?, ?, ?)`
      ).bind(u1, u2, now),
    ]);

    return c.json({
      id: reciprocal.id,
      status: 'accepted',
      alreadySent: false,
      autoAccepted: true,
    });
  }

  const id = generateId(16);

  await c.env.DB.prepare(
    `INSERT INTO friend_requests (id, from_code, to_code, from_name, status, created_at, updated_at)
     VALUES (?, ?, ?, ?, 'pending', ?, ?)`
  )
    .bind(id, cleanFrom, cleanTo, fromName ? String(fromName).trim() : null, now, now)
    .run();

  return c.json({ id, status: 'pending', alreadySent: false, autoAccepted: false });
});

// 2. Poll incoming pending requests AND accepted requests for a user (bidirectional sync)
friendsApp.get('/requests/:myCode', requireFriendAuth, async (c) => {
  const myCode = c.req.param('myCode');
  if (!myCode) {
    return c.json({ error: 'myCode is required' }, 400);
  }

  const cleanCode = String(myCode).trim().toUpperCase();
  if (c.get('friendCode') !== cleanCode) {
    return c.json({ error: 'Forbidden: cannot access friend requests for another code' }, 403);
  }

  // Requests addressed TO me that are pending
  const incoming = await c.env.DB.prepare(
    `SELECT id, from_code AS fromCode, to_code AS toCode, from_name AS fromName, created_at AS createdAt
     FROM friend_requests
     WHERE to_code = ? AND status = 'pending'
     ORDER BY created_at DESC`
  )
    .bind(cleanCode)
    .all();

  // Requests sent BY me that were accepted
  const accepted = await c.env.DB.prepare(
    `SELECT id, from_code AS fromCode, to_code AS toCode, from_name AS fromName, updated_at AS updatedAt
     FROM friend_requests
     WHERE from_code = ? AND status = 'accepted'
     ORDER BY updated_at DESC`
  )
    .bind(cleanCode)
    .all();

  return c.json({
    requests: incoming.results || [],
    accepted: accepted.results || [],
  });
});

// 3. Acknowledge an accepted request (mark synced)
friendsApp.post('/ack', requireFriendAuth, async (c) => {
  const body = await c.req.json<{ requestId?: string }>().catch(() => ({}) as any);
  const { requestId } = body;
  if (!requestId) {
    return c.json({ error: 'requestId is required' }, 400);
  }

  const cleanCode = c.get('friendCode')!;
  const now = Date.now();

  await c.env.DB.prepare(
    `UPDATE friend_requests SET status = 'synced', updated_at = ? WHERE id = ? AND from_code = ?`
  )
    .bind(now, requestId, cleanCode)
    .run();

  return c.json({ ok: true });
});

// 4. Accept a friend request
friendsApp.post('/accept', requireFriendAuth, async (c) => {
  const body = await c.req.json<{ requestId?: string }>().catch(() => ({}) as any);
  const { requestId } = body;
  if (!requestId) {
    return c.json({ error: 'requestId is required' }, 400);
  }

  const cleanCode = c.get('friendCode')!;
  const request = await c.env.DB.prepare(`SELECT * FROM friend_requests WHERE id = ?`)
    .bind(requestId)
    .first<FriendRequestRow>();

  if (!request) {
    return c.json({ error: 'Friend request not found' }, 404);
  }

  if (request.to_code !== cleanCode) {
    return c.json({ error: 'Unauthorized to accept this request' }, 403);
  }

  if (request.status !== 'pending') {
    return c.json({ error: `Request is not pending (current: ${request.status})` }, 400);
  }

  const now = Date.now();
  const u1 = cleanCode < request.from_code ? cleanCode : request.from_code;
  const u2 = cleanCode < request.from_code ? request.from_code : cleanCode;

  // Atomically update request and insert friend relationship
  await c.env.DB.batch([
    c.env.DB.prepare(
      `UPDATE friend_requests SET status = 'accepted', updated_at = ? WHERE id = ?`
    ).bind(now, requestId),
    c.env.DB.prepare(
      `INSERT OR IGNORE INTO friends (user_a, user_b, created_at) VALUES (?, ?, ?)`
    ).bind(u1, u2, now),
  ]);

  return c.json({
    ok: true,
    fromCode: request.from_code,
    fromName: request.from_name,
  });
});

// 5. Decline a friend request
friendsApp.post('/decline', requireFriendAuth, async (c) => {
  const body = await c.req.json<{ requestId?: string }>().catch(() => ({}) as any);
  const { requestId } = body;
  if (!requestId) {
    return c.json({ error: 'requestId is required' }, 400);
  }

  const cleanCode = c.get('friendCode')!;
  const request = await c.env.DB.prepare(`SELECT * FROM friend_requests WHERE id = ?`)
    .bind(requestId)
    .first<FriendRequestRow>();

  if (!request) {
    return c.json({ error: 'Friend request not found' }, 404);
  }

  if (request.to_code !== cleanCode) {
    return c.json({ error: 'Unauthorized to decline this request' }, 403);
  }

  if (request.status !== 'pending') {
    return c.json({ error: `Request is not pending (current: ${request.status})` }, 400);
  }

  const now = Date.now();
  await c.env.DB.prepare(
    `UPDATE friend_requests SET status = 'declined', updated_at = ? WHERE id = ?`
  )
    .bind(now, requestId)
    .run();

  return c.json({ ok: true });
});

// 5a. Cancel a sent friend request (caller must be sender)
friendsApp.post('/cancel', requireFriendAuth, async (c) => {
  const body = await c.req.json<{ requestId?: string }>().catch(() => ({}) as any);
  const { requestId } = body;
  if (!requestId) {
    return c.json({ error: 'requestId is required' }, 400);
  }

  const cleanCode = c.get('friendCode')!;
  const request = await c.env.DB.prepare(`SELECT * FROM friend_requests WHERE id = ?`)
    .bind(requestId)
    .first<FriendRequestRow>();

  if (!request) {
    return c.json({ error: 'Friend request not found' }, 404);
  }

  if (request.from_code !== cleanCode) {
    return c.json({ error: 'Unauthorized to cancel this request' }, 403);
  }

  if (request.status !== 'pending') {
    return c.json({ error: `Only pending requests can be cancelled (current: ${request.status})` }, 400);
  }

  const now = Date.now();
  await c.env.DB.prepare(
    `UPDATE friend_requests SET status = 'cancelled', updated_at = ? WHERE id = ?`
  )
    .bind(now, requestId)
    .run();

  return c.json({ ok: true });
});

// 5b. Resend an expired or cancelled friend request
friendsApp.post('/resend', requireFriendAuth, async (c) => {
  const body = await c.req.json<{ requestId?: string }>().catch(() => ({}) as any);
  const { requestId } = body;
  if (!requestId) {
    return c.json({ error: 'requestId is required' }, 400);
  }

  const cleanCode = c.get('friendCode')!;
  const request = await c.env.DB.prepare(`SELECT * FROM friend_requests WHERE id = ?`)
    .bind(requestId)
    .first<FriendRequestRow>();

  if (!request) {
    return c.json({ error: 'Friend request not found' }, 404);
  }

  if (request.from_code !== cleanCode) {
    return c.json({ error: 'Unauthorized to resend this request' }, 403);
  }

  if (request.status !== 'cancelled' && request.status !== 'expired') {
    return c.json({ error: `Only cancelled or expired requests can be resent (current: ${request.status})` }, 400);
  }

  const now = Date.now();
  await c.env.DB.prepare(
    `UPDATE friend_requests SET status = 'pending', created_at = ?, updated_at = ? WHERE id = ?`
  )
    .bind(now, now, requestId)
    .run();

  return c.json({ ok: true });
});

// 5c. Remove a friend relationship
friendsApp.post('/remove', requireFriendAuth, async (c) => {
  const body = await c.req.json<{ friendCode?: string }>().catch(() => ({}) as any);
  const { friendCode } = body;
  if (!friendCode) {
    return c.json({ error: 'friendCode is required' }, 400);
  }

  const cleanCode = c.get('friendCode')!;
  const otherCode = String(friendCode).trim().toUpperCase();
  const u1 = cleanCode < otherCode ? cleanCode : otherCode;
  const u2 = cleanCode < otherCode ? otherCode : cleanCode;

  await c.env.DB.prepare(`DELETE FROM friends WHERE user_a = ? AND user_b = ?`)
    .bind(u1, u2)
    .run();

  return c.json({ ok: true });
});

// 5d. Get accepted friends list
friendsApp.get('/list/:myCode', requireFriendAuth, async (c) => {
  const myCode = c.req.param('myCode');
  const cleanCode = String(myCode).trim().toUpperCase();
  if (c.get('friendCode') !== cleanCode) {
    return c.json({ error: 'Forbidden: cannot access friend list for another code' }, 403);
  }

  const rows = await c.env.DB.prepare(
    `SELECT
       CASE WHEN f.user_a = ? THEN f.user_b ELSE f.user_a END AS friendCode,
       f.created_at AS createdAt,
       fa.username
     FROM friends f
     LEFT JOIN friend_accounts fa ON fa.friend_code = (CASE WHEN f.user_a = ? THEN f.user_b ELSE f.user_a END)
     WHERE f.user_a = ? OR f.user_b = ?
     ORDER BY f.created_at DESC`
  )
    .bind(cleanCode, cleanCode, cleanCode, cleanCode)
    .all<{ friendCode: string; createdAt: number; username: string | null }>();

  const enriched = (rows.results || []).map((r) => ({
    friendCode: r.friendCode,
    username: r.username || null,
    createdAt: r.createdAt,
  }));

  return c.json({ friends: enriched });
});

// 5e. Get sent friend requests (pending and expired)
friendsApp.get('/sent/:myCode', requireFriendAuth, async (c) => {
  const myCode = c.req.param('myCode');
  const cleanCode = String(myCode).trim().toUpperCase();
  if (c.get('friendCode') !== cleanCode) {
    return c.json({ error: 'Forbidden: cannot access sent requests for another code' }, 403);
  }

  const rows = await c.env.DB.prepare(
    `SELECT
       fr.id,
       fr.from_code AS fromCode,
       fr.to_code AS toCode,
       fr.from_name AS fromName,
       fr.status,
       fr.created_at AS createdAt,
       fr.updated_at AS updatedAt,
       fa.username AS toName
     FROM friend_requests fr
     LEFT JOIN friend_accounts fa ON fa.friend_code = fr.to_code
     WHERE fr.from_code = ?
     ORDER BY fr.updated_at DESC`
  )
    .bind(cleanCode)
    .all<{
      id: string;
      fromCode: string;
      toCode: string;
      fromName: string | null;
      status: string;
      createdAt: number;
      updatedAt: number;
      toName: string | null;
    }>();

  const now = Date.now();
  const thirtyDaysMs = 30 * 24 * 60 * 60 * 1000;
  const expiredIds: string[] = [];

  const enriched = (rows.results || []).map((r) => {
    let currentStatus = r.status;
    if (currentStatus === 'pending' && now - r.createdAt > thirtyDaysMs) {
      currentStatus = 'expired';
      expiredIds.push(r.id);
    }
    return {
      id: r.id,
      fromCode: r.fromCode,
      toCode: r.toCode,
      fromName: r.fromName,
      status: currentStatus,
      createdAt: r.createdAt,
      updatedAt: r.updatedAt,
      toName: r.toName || null,
    };
  });

  if (expiredIds.length > 0) {
    const placeholders = expiredIds.map(() => '?').join(',');
    await c.env.DB.prepare(
      `UPDATE friend_requests SET status = 'expired' WHERE id IN (${placeholders})`
    )
      .bind(...expiredIds)
      .run();
  }

  return c.json({ requests: enriched });
});

// 5f. Create short universal invite link
friendsApp.post('/invite', requireFriendAuth, async (c) => {
  const cleanCode = c.get('friendCode')!;
  const body = await c.req.json<{ fromName?: string }>().catch(() => ({}) as any);
  const { fromName } = body;

  const now = Date.now();
  const id = generateId(16);
  const inviteCode = generateInviteCode();
  const expiresAt = now + 30 * 24 * 60 * 60 * 1000; // 30 days TTL

  const account = await c.env.DB.prepare(
    `SELECT username FROM friend_accounts WHERE friend_code = ?`
  )
    .bind(cleanCode)
    .first<{ username: string | null }>();

  const effectiveName = fromName
    ? String(fromName).trim()
    : account?.username
    ? account.username
    : null;

  await c.env.DB.prepare(
    `INSERT INTO invites (id, invite_code, created_by, from_name, expires_at, status, created_at)
     VALUES (?, ?, ?, ?, ?, 'valid', ?)`
  )
    .bind(id, inviteCode, cleanCode, effectiveName, expiresAt, now)
    .run();

  return c.json({
    code: inviteCode,
    url: `https://kioku.app/i/${inviteCode}`,
  });
});

// 5g. Resolve public invite code
friendsApp.get('/invite/:code', async (c) => {
  const code = c.req.param('code');
  const result = await resolveInviteDetails(code, c.env.DB);
  if (result.status === 'invalid') {
    return c.json(result, 404);
  }
  return c.json(result);
});

// 5h. Update profile username
friendsApp.post('/profile', requireFriendAuth, async (c) => {
  const body = await c.req.json<{ username?: string }>().catch(() => ({}) as any);
  const { username } = body;
  if (!username) {
    return c.json({ error: 'username is required' }, 400);
  }

  const cleanCode = c.get('friendCode')!;
  const cleanName = String(username).trim();

  await c.env.DB.prepare(`UPDATE friend_accounts SET username = ? WHERE friend_code = ?`)
    .bind(cleanName, cleanCode)
    .run();

  return c.json({ ok: true, username: cleanName });
});

// --- ALBUM INVITATIONS & CROSS-ACCOUNT SYNC (Server-Authoritative Membership) ---

// 6. Send in-app album invite to a friend
friendsApp.post('/albums/invite', requireFriendAuth, async (c) => {
  const body = await c.req.json<{
    albumId?: string;
    albumName?: string;
    toCode?: string;
    fromName?: string;
    claimToken?: string;
    inviterPubKey?: string;
  }>().catch(() => ({}) as any);

  const { albumId, albumName, toCode, fromName, claimToken, inviterPubKey } = body;
  const fromCode = c.get('friendCode')!;

  if (!albumId || !toCode) {
    return c.json({ error: 'albumId and toCode are required' }, 400);
  }

  const cleanFrom = fromCode;
  const cleanTo = String(toCode).trim().toUpperCase();

  if (cleanFrom === cleanTo) {
    return c.json({ error: 'Cannot invite yourself to an album' }, 400);
  }

  // Verify recipient friend code exists (Section 7)
  const recipient = await c.env.DB.prepare(
    `SELECT friend_code FROM friend_accounts WHERE friend_code = ?`
  )
    .bind(cleanTo)
    .first<{ friend_code: string }>();

  if (!recipient) {
    return c.json({ error: 'Recipient friend code does not exist' }, 404);
  }

  const now = Date.now();

  // Ensure album exists in canonical server albums table and inviter is active member/owner
  const callerMember = await c.env.DB.prepare(
    `SELECT role, status FROM album_members WHERE album_id = ? AND user_id = ? AND status = 'active'`
  )
    .bind(albumId, cleanFrom)
    .first<{ role: string; status: string }>();

  if (!callerMember) {
    // If not registered yet, auto-register this album with caller as active owner
    await c.env.DB.batch([
      c.env.DB.prepare(
        `INSERT OR IGNORE INTO albums (id, owner_user_id, title, storage_type, current_epoch, created_at, updated_at)
         VALUES (?, ?, ?, 'local', 1, ?, ?)`
      ).bind(albumId, cleanFrom, albumName || 'Shared Album', now, now),
      c.env.DB.prepare(
        `INSERT OR REPLACE INTO album_members (album_id, user_id, role, status, joined_at, updated_at)
         VALUES (?, ?, 'owner', 'active', ?, ?)`
      ).bind(albumId, cleanFrom, now, now),
    ]);
  }

  const id = generateId(16);

  // Atomically create invitation and pending album membership
  await c.env.DB.batch([
    c.env.DB.prepare(
      `INSERT INTO album_invites (id, album_id, album_name, from_code, to_code, from_name, claim_token, inviter_pub_key, status, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'pending', ?, ?)`
    ).bind(
      id,
      albumId,
      albumName || 'Shared Album',
      cleanFrom,
      cleanTo,
      fromName ? String(fromName).trim() : null,
      claimToken || null,
      inviterPubKey || null,
      now,
      now
    ),
    c.env.DB.prepare(
      `INSERT OR IGNORE INTO album_members (album_id, user_id, role, status, joined_at, updated_at)
       VALUES (?, ?, 'member', 'pending', ?, ?)`
    ).bind(albumId, cleanTo, now, now),
  ]);

  return c.json({ id, status: 'pending' });
});

// 7. Poll incoming album invites for a user
friendsApp.get('/albums/invites/:myCode', requireFriendAuth, async (c) => {
  const myCode = c.req.param('myCode');
  if (!myCode) {
    return c.json({ error: 'myCode is required' }, 400);
  }

  const cleanCode = String(myCode).trim().toUpperCase();
  if (c.get('friendCode') !== cleanCode) {
    return c.json({ error: 'Forbidden: cannot access album invites for another code' }, 403);
  }

  const rows = await c.env.DB.prepare(
    `SELECT id, album_id AS albumId, album_name AS albumName, from_code AS fromCode,
            to_code AS toCode, from_name AS fromName, claim_token AS claimToken,
            inviter_pub_key AS inviterPubKey, created_at AS createdAt
     FROM album_invites
     WHERE to_code = ? AND status = 'pending'
     ORDER BY created_at DESC`
  )
    .bind(cleanCode)
    .all();

  return c.json({ invites: rows.results || [] });
});

// 8. Accept an album invite (Section 7: atomically updates invitation and creates active server membership)
friendsApp.post('/albums/accept', requireFriendAuth, async (c) => {
  const body = await c.req.json<{ inviteId?: string }>().catch(() => ({}) as any);
  const { inviteId } = body;
  if (!inviteId) {
    return c.json({ error: 'inviteId is required' }, 400);
  }

  const cleanCode = c.get('friendCode')!;
  const invite = await c.env.DB.prepare(`SELECT * FROM album_invites WHERE id = ?`)
    .bind(inviteId)
    .first<AlbumInviteRow>();

  if (!invite) {
    return c.json({ error: 'Album invite not found' }, 404);
  }

  if (invite.to_code !== cleanCode) {
    return c.json({ error: 'Unauthorized to accept this album invite' }, 403);
  }

  if (invite.status !== 'pending') {
    return c.json({ error: `Invite is not pending (current: ${invite.status})` }, 400);
  }

  const now = Date.now();

  // Atomically mark invitation accepted AND record active album membership in D1
  await c.env.DB.batch([
    c.env.DB.prepare(
      `UPDATE album_invites SET status = 'accepted', updated_at = ? WHERE id = ?`
    ).bind(now, inviteId),
    c.env.DB.prepare(
      `INSERT OR REPLACE INTO album_members (album_id, user_id, role, status, joined_at, updated_at)
       VALUES (?, ?, 'member', 'active', ?, ?)`
    ).bind(invite.album_id, cleanCode, now, now),
  ]);

  return c.json({
    ok: true,
    albumId: invite.album_id,
    albumName: invite.album_name,
    fromCode: invite.from_code,
    fromName: invite.from_name,
    claimToken: invite.claim_token,
    inviterPubKey: invite.inviter_pub_key,
  });
});

// 9. Decline an album invite
friendsApp.post('/albums/decline', requireFriendAuth, async (c) => {
  const body = await c.req.json<{ inviteId?: string }>().catch(() => ({}) as any);
  const { inviteId } = body;
  if (!inviteId) {
    return c.json({ error: 'inviteId is required' }, 400);
  }

  const cleanCode = c.get('friendCode')!;
  const invite = await c.env.DB.prepare(`SELECT * FROM album_invites WHERE id = ?`)
    .bind(inviteId)
    .first<AlbumInviteRow>();

  if (!invite) {
    return c.json({ error: 'Album invite not found' }, 404);
  }

  if (invite.to_code !== cleanCode) {
    return c.json({ error: 'Unauthorized to decline this album invite' }, 403);
  }

  const now = Date.now();
  await c.env.DB.batch([
    c.env.DB.prepare(
      `UPDATE album_invites SET status = 'declined', updated_at = ? WHERE id = ?`
    ).bind(now, inviteId),
    c.env.DB.prepare(
      `UPDATE album_members SET status = 'revoked', updated_at = ? WHERE album_id = ? AND user_id = ?`
    ).bind(now, invite.album_id, cleanCode),
  ]);

  return c.json({ ok: true });
});
