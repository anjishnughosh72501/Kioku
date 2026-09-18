// src/routes/legacy.ts
// Preserves legacy demo mode /auth and /media endpoints for full backward compatibility.

import { Hono } from 'hono';
import { AppEnv, GroupRow, UserRow, MediaRow } from '../types';
import { generateId, signJwt } from '../crypto';
import { requireLegacyAuth } from '../middleware/auth';

export const legacyAuthApp = new Hono<AppEnv>();
export const legacyMediaApp = new Hono<AppEnv>();

// POST /auth/groups
legacyAuthApp.post('/groups', async (c) => {
  const body = await c.req.json<{ groupName?: string }>().catch(() => ({}) as any);
  const { groupName } = body;
  if (!groupName || typeof groupName !== 'string' || !groupName.trim()) {
    return c.json({ error: 'groupName is required' }, 400);
  }

  const cleanName = groupName.trim();
  if (cleanName.length > 80) {
    return c.json({ error: 'groupName must be 80 characters or fewer' }, 400);
  }

  const id = generateId(16);
  const inviteCode = generateId(8).toUpperCase();

  await c.env.DB.prepare(
    `INSERT INTO groups (id, name, invite_code, drive_folder_id) VALUES (?, ?, ?, ?)`
  )
    .bind(id, cleanName, inviteCode, 'worker-drive-folder-id')
    .run();

  return c.json({ groupId: id, inviteCode });
});

// POST /auth/join
legacyAuthApp.post('/join', async (c) => {
  const body = await c.req.json<{ inviteCode?: string; name?: string }>().catch(() => ({}) as any);
  const { inviteCode, name } = body;
  if (!inviteCode || !name) {
    return c.json({ error: 'inviteCode and name are required' }, 400);
  }

  const cleanInvite = String(inviteCode).trim().toUpperCase();
  const cleanName = String(name).trim();

  const group = await c.env.DB.prepare(`SELECT * FROM groups WHERE invite_code = ?`)
    .bind(cleanInvite)
    .first<GroupRow>();

  if (!group) {
    return c.json({ error: 'Invalid invite code' }, 404);
  }

  const userId = generateId(16);
  await c.env.DB.prepare(`INSERT INTO users (id, name, group_id) VALUES (?, ?, ?)`).bind(
    userId,
    cleanName,
    group.id
  ).run();

  const secret = c.env.JWT_SECRET || 'default-dev-secret-change-in-production-please';
  const token = await signJwt(
    { userId, groupId: group.id, name: cleanName },
    secret,
    30 * 24 * 60 * 60 // 30 days
  );

  return c.json({ token, userId, groupId: group.id, groupName: group.name });
});

// GET /auth/me
legacyAuthApp.get('/me', requireLegacyAuth, async (c) => {
  const user = c.get('legacyUser')!;
  const group = await c.env.DB.prepare(`SELECT * FROM groups WHERE id = ?`)
    .bind(user.groupId)
    .first<GroupRow>();

  if (!group) {
    return c.json({ error: 'Group not found' }, 404);
  }

  return c.json({
    userId: user.userId,
    name: user.name,
    groupId: group.id,
    groupName: group.name,
    inviteCode: group.invite_code,
    role: 'member',
  });
});

// POST /auth/refresh
legacyAuthApp.post('/refresh', requireLegacyAuth, async (c) => {
  const user = c.get('legacyUser')!;
  const secret = c.env.JWT_SECRET || 'default-dev-secret-change-in-production-please';
  const token = await signJwt(
    { userId: user.userId, groupId: user.groupId, name: user.name },
    secret,
    30 * 24 * 60 * 60
  );

  return c.json({ token, userId: user.userId, groupId: user.groupId, name: user.name });
});

// GET /media/feed
legacyMediaApp.get('/feed', requireLegacyAuth, async (c) => {
  const user = c.get('legacyUser')!;
  const sort = c.req.query('sort') || 'day';
  const uploaderId = c.req.query('uploaderId');
  const page = Math.max(1, parseInt(c.req.query('page') || '1', 10));
  const pageSize = Math.min(100, Math.max(1, parseInt(c.req.query('pageSize') || '30', 10)));

  let query = `
    SELECT media.*, users.name AS uploader_name
    FROM media
    JOIN users ON users.id = media.uploader_id
    WHERE media.group_id = ?
  `;
  const params: any[] = [user.groupId];

  if (uploaderId) {
    query += ` AND media.uploader_id = ?`;
    params.push(uploaderId);
  }

  const orderBy = sort === 'uploader' ? 'media.uploader_id, media.taken_at' : 'media.taken_at';
  query += ` ORDER BY ${orderBy} DESC LIMIT ? OFFSET ?`;
  params.push(pageSize, (page - 1) * pageSize);

  const rows = await c.env.DB.prepare(query).bind(...params).all<MediaRow>();

  const items = (rows.results || []).map((row) => ({
    id: row.id,
    type: row.type,
    caption: row.caption,
    takenAt: row.taken_at,
    uploaderName: row.uploader_name,
    thumbnailUrl: `https://drive.google.com/thumbnail?id=${row.drive_file_id}&sz=w500`,
    viewUrl: `https://drive.google.com/uc?export=view&id=${row.drive_file_id}`,
  }));

  return c.json({ items });
});

// GET /media/uploaders
legacyMediaApp.get('/uploaders', requireLegacyAuth, async (c) => {
  const user = c.get('legacyUser')!;
  const rows = await c.env.DB.prepare(
    `SELECT DISTINCT users.id, users.name FROM users WHERE users.group_id = ?`
  )
    .bind(user.groupId)
    .all<{ id: string; name: string }>();

  return c.json({ uploaders: rows.results || [] });
});
