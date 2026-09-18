// src/routes/albums.ts
// Canonical Server-Side Album Model and Membership Management

import { Hono } from 'hono';
import { AppEnv, AlbumRow, AlbumMemberRow } from '../types';
import { generateId } from '../crypto';
import { requireFriendAuth } from '../middleware/auth';

export const albumsApp = new Hono<AppEnv>();

// 1. Create a shareable album and register the caller as the active owner
albumsApp.post('/', requireFriendAuth, async (c) => {
  const userCode = c.get('friendCode')!;
  const body = await c.req.json<{
    id?: string;
    title?: string;
    name?: string;
    storageType?: string;
    storageReference?: string;
  }>().catch(() => ({}) as any);

  const title = body.title || body.name;
  if (!title || typeof title !== 'string' || !title.trim()) {
    return c.json({ error: 'title or name is required' }, 400);
  }

  const cleanTitle = title.trim();
  const albumId =
    body.id && typeof body.id === 'string' && body.id.trim().length > 0
      ? body.id.trim()
      : `album_${generateId(16)}`;
  const now = Date.now();
  const resolvedStorage = body.storageType || 'local';

  // Check if album ID already exists
  const existing = await c.env.DB.prepare(`SELECT * FROM albums WHERE id = ?`)
    .bind(albumId)
    .first<AlbumRow>();

  if (existing) {
    // If caller is already owner or member, return existing
    const member = await c.env.DB.prepare(
      `SELECT * FROM album_members WHERE album_id = ? AND user_id = ? AND status = 'active'`
    )
      .bind(albumId, userCode)
      .first<AlbumMemberRow>();

    if (member) {
      return c.json({
        album: {
          id: existing.id,
          ownerUserId: existing.owner_user_id,
          ownerCode: existing.owner_user_id,
          title: existing.title,
          name: existing.title,
          storageType: existing.storage_type,
          currentEpoch: existing.current_epoch,
          role: member.role,
          status: member.status,
          createdAt: existing.created_at,
          updatedAt: existing.updated_at,
        },
      });
    }
    return c.json({ error: 'Album ID collision' }, 409);
  }

  // Atomically create album and owner membership
  await c.env.DB.batch([
    c.env.DB.prepare(
      `INSERT INTO albums (id, owner_user_id, title, storage_type, storage_reference, current_epoch, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, 1, ?, ?)`
    ).bind(albumId, userCode, cleanTitle, resolvedStorage, body.storageReference || null, now, now),
    c.env.DB.prepare(
      `INSERT INTO album_members (album_id, user_id, role, status, joined_at, updated_at)
       VALUES (?, ?, 'owner', 'active', ?, ?)`
    ).bind(albumId, userCode, now, now),
  ]);

  return c.json(
    {
      album: {
        id: albumId,
        ownerUserId: userCode,
        ownerCode: userCode,
        title: cleanTitle,
        name: cleanTitle,
        storageType: resolvedStorage,
        currentEpoch: 1,
        role: 'owner',
        status: 'active',
        createdAt: now,
        updatedAt: now,
      },
    },
    201
  );
});

// 2. Retrieve all active album memberships for the authenticated user (Critical for guest reopening album)
albumsApp.get('/', requireFriendAuth, async (c) => {
  const userCode = c.get('friendCode')!;

  const rows = await c.env.DB.prepare(
    `SELECT
       a.id,
       a.owner_user_id AS ownerUserId,
       a.owner_user_id AS ownerCode,
       a.title,
       a.title AS name,
       a.storage_type AS storageType,
       a.current_epoch AS currentEpoch,
       a.created_at AS createdAt,
       a.updated_at AS updatedAt,
       m.role,
       m.status,
       m.joined_at AS joinedAt
     FROM album_members m
     JOIN albums a ON a.id = m.album_id
     WHERE m.user_id = ? AND m.status = 'active'
     ORDER BY a.created_at DESC`
  )
    .bind(userCode)
    .all();

  return c.json({ albums: rows.results || [] });
});

// 3. Get specific album details (Must be an active member)
albumsApp.get('/:albumId', requireFriendAuth, async (c) => {
  const userCode = c.get('friendCode')!;
  const albumId = c.req.param('albumId');

  const row = await c.env.DB.prepare(
    `SELECT
       a.id,
       a.owner_user_id AS ownerUserId,
       a.owner_user_id AS ownerCode,
       a.title,
       a.title AS name,
       a.storage_type AS storageType,
       a.current_epoch AS currentEpoch,
       a.created_at AS createdAt,
       a.updated_at AS updatedAt,
       m.role,
       m.status,
       m.joined_at AS joinedAt
     FROM album_members m
     JOIN albums a ON a.id = m.album_id
     WHERE m.album_id = ? AND m.user_id = ? AND m.status = 'active'`
  )
    .bind(albumId, userCode)
    .first();

  if (!row) {
    const exists = await c.env.DB.prepare(`SELECT id FROM albums WHERE id = ?`).bind(albumId).first();
    if (exists) {
      return c.json({ error: 'Forbidden: not an active member of this album' }, 403);
    }
    return c.json({ error: 'Album not found' }, 404);
  }
  const members = await c.env.DB.prepare(
    `SELECT
       m.user_id AS userId,
       m.user_id AS userCode,
       m.role,
       m.status,
       m.joined_at AS joinedAt,
       fa.username AS displayName
     FROM album_members m
     LEFT JOIN friend_accounts fa ON fa.friend_code = m.user_id
     WHERE m.album_id = ? AND m.status != 'revoked'
     ORDER BY m.joined_at ASC`
  )
    .bind(albumId)
    .all();

  return c.json({ album: row, members: members.results || [] });
});

// 4. Get members of an album (Must be an active member)
albumsApp.get('/:albumId/members', requireFriendAuth, async (c) => {
  const userCode = c.get('friendCode')!;
  const albumId = c.req.param('albumId');

  // Verify caller is active member
  const callerMember = await c.env.DB.prepare(
    `SELECT role, status FROM album_members WHERE album_id = ? AND user_id = ? AND status = 'active'`
  )
    .bind(albumId, userCode)
    .first<{ role: string; status: string }>();

  if (!callerMember) {
    return c.json({ error: 'Forbidden: not an active member of this album' }, 403);
  }

  const rows = await c.env.DB.prepare(
    `SELECT
       m.user_id AS userId,
       m.user_id AS userCode,
       m.role,
       m.status,
       m.joined_at AS joinedAt,
       fa.username AS displayName
     FROM album_members m
     LEFT JOIN friend_accounts fa ON fa.friend_code = m.user_id
     WHERE m.album_id = ? AND m.status != 'revoked'
     ORDER BY m.joined_at ASC`
  )
    .bind(albumId)
    .all();

  return c.json({ members: rows.results || [] });
});

// 5. Remove an album member (Owner can remove any member, member can remove self)
// Triggers an epoch increment on the album so clients rotate the collection key
albumsApp.post('/:albumId/members/remove', requireFriendAuth, async (c) => {
  const userCode = c.get('friendCode')!;
  const albumId = c.req.param('albumId');
  const body = await c.req.json<{ friendCode?: string; memberCode?: string }>().catch(() => ({}) as any);
  const code = body.friendCode || body.memberCode;

  if (!code) {
    return c.json({ error: 'friendCode or memberCode is required' }, 400);
  }

  const targetCode = code.trim().toUpperCase();

  // Verify caller membership
  const callerMember = await c.env.DB.prepare(
    `SELECT role, status FROM album_members WHERE album_id = ? AND user_id = ? AND status = 'active'`
  )
    .bind(albumId, userCode)
    .first<{ role: string; status: string }>();

  if (!callerMember) {
    return c.json({ error: 'Forbidden: not an active member of this album' }, 403);
  }

  // Only owner can remove another member. Member can remove themselves (leave)
  if (callerMember.role !== 'owner' && targetCode !== userCode) {
    return c.json({ error: 'Only album owner can remove other members' }, 403);
  }

  // Cannot remove owner unless another owner is designated
  if (targetCode === userCode && callerMember.role === 'owner') {
    return c.json({ error: 'Owner cannot leave album without transferring ownership' }, 400);
  }

  // Check target member exists
  const targetMember = await c.env.DB.prepare(
    `SELECT role, status FROM album_members WHERE album_id = ? AND user_id = ?`
  )
    .bind(albumId, targetCode)
    .first<{ role: string; status: string }>();

  if (!targetMember || targetMember.status === 'revoked') {
    return c.json({ error: 'Member not found or already revoked' }, 404);
  }

  const now = Date.now();

  // Atomically revoke membership and advance album key epoch
  await c.env.DB.batch([
    c.env.DB.prepare(
      `UPDATE album_members SET status = 'revoked', updated_at = ? WHERE album_id = ? AND user_id = ?`
    ).bind(now, albumId, targetCode),
    c.env.DB.prepare(
      `UPDATE albums SET current_epoch = current_epoch + 1, updated_at = ? WHERE id = ?`
    ).bind(now, albumId),
  ]);

  const updatedAlbum = await c.env.DB.prepare(`SELECT current_epoch FROM albums WHERE id = ?`)
    .bind(albumId)
    .first<{ current_epoch: number }>();

  return c.json({
    ok: true,
    albumId,
    revokedUser: targetCode,
    currentEpoch: updatedAlbum?.current_epoch ?? 2,
  });
});
