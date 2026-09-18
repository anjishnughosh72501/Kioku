// src/routes/flashbacks.ts
import { Hono } from 'hono';
import { AppEnv, FlashbackRow, GroupRow, MediaRow } from '../types';
import { generateId, verifyJwt } from '../crypto';

export const flashbacksApp = new Hono<AppEnv>();

const PERIOD_LABELS: Record<string, { periodTitle: string; subtitle: string }> = {
  yearly: { periodTitle: '1 Year Ago Today', subtitle: "From last year's album" },
  monthly: { periodTitle: "Last Month's Album", subtitle: 'From last month' },
  weekly: { periodTitle: 'A Passing Memory', subtitle: 'From this week' },
};

const PERIODS: Record<string, number> = {
  weekly: 7,
  monthly: 30,
  yearly: 365,
};

function pickRandom<T>(arr: T[], n: number): T[] {
  const copy = [...arr];
  const picked: T[] = [];
  while (copy.length && picked.length < n) {
    const idx = Math.floor(Math.random() * copy.length);
    picked.push(copy.splice(idx, 1)[0]);
  }
  return picked;
}

export async function generateForGroup(group: { id: string; name: string }, today: Date, db: D1Database) {
  const todayStr = today.toISOString().slice(0, 10);

  for (const [period, daysAgo] of Object.entries(PERIODS)) {
    const targetDate = new Date(today);
    targetDate.setDate(targetDate.getDate() - daysAgo);

    const windowStart = new Date(targetDate);
    windowStart.setDate(windowStart.getDate() - 2);

    const windowEnd = new Date(targetDate);
    windowEnd.setDate(windowEnd.getDate() + 2);

    const candidates = await db
      .prepare(`SELECT id FROM media WHERE group_id = ? AND taken_at BETWEEN ? AND ?`)
      .bind(group.id, windowStart.toISOString(), windowEnd.toISOString())
      .all<{ id: string }>();

    const candidateRows = candidates.results || [];
    if (candidateRows.length === 0) continue;

    const chosen = pickRandom(candidateRows, 6).map((c) => c.id);

    await db
      .prepare(
        `INSERT OR REPLACE INTO flashbacks (id, group_id, period, generated_for, media_ids)
         VALUES (?, ?, ?, ?, ?)`
      )
      .bind(generateId(16), group.id, period, todayStr, JSON.stringify(chosen))
      .run();
  }
}

export async function runFlashbackGeneration(db: D1Database) {
  const groupsResult = await db.prepare(`SELECT * FROM groups`).all<GroupRow>();
  const groups = groupsResult.results || [];
  const today = new Date();
  let count = 0;

  for (const group of groups) {
    try {
      await generateForGroup(group, today, db);
      count++;
    } catch (err) {
      console.error(`[flashbacks] Failed for group ${group.id}:`, err);
    }
  }

  return { generated: count, total: groups.length };
}

// GET /flashbacks
flashbacksApp.get('/', async (c) => {
  const authHeader = c.req.header('authorization');
  let groupId: string | null = null;

  if (authHeader && authHeader.startsWith('Bearer ')) {
    const token = authHeader.split(' ')[1];
    const secret = c.env.JWT_SECRET || 'default-dev-secret-change-in-production-please';
    try {
      const decoded = await verifyJwt<{ groupId?: string; friendCode?: string }>(token, secret);
      groupId = decoded.groupId || decoded.friendCode || null;
    } catch (_) {}
  }

  if (!groupId) {
    groupId = c.req.query('groupId') || 'default-group';
  }

  const today = new Date().toISOString().slice(0, 10);

  const setsResult = await c.env.DB
    .prepare(`SELECT * FROM flashbacks WHERE group_id = ? AND generated_for = ?`)
    .bind(groupId, today)
    .all<FlashbackRow>();

  const sets = setsResult.results || [];

  const result = await Promise.all(
    sets.map(async (set) => {
      let mediaIds: string[] = [];
      try {
        const parsed = JSON.parse(set.media_ids);
        if (Array.isArray(parsed)) {
          mediaIds = parsed.filter((id) => typeof id === 'string');
        }
      } catch {
        // Corrupt media_ids
      }

      let items: any[] = [];
      if (mediaIds.length > 0) {
        const placeholders = mediaIds.map(() => '?').join(',');
        const mediaQuery = `
          SELECT media.*, users.name AS uploader_name
          FROM media
          JOIN users ON users.id = media.uploader_id
          WHERE media.id IN (${placeholders})
        `;
        const itemsResult = await c.env.DB.prepare(mediaQuery).bind(...mediaIds).all<MediaRow>();
        items = (itemsResult.results || []).map((row) => ({
          id: row.id,
          type: row.type,
          caption: row.caption,
          takenAt: row.taken_at,
          uploaderName: row.uploader_name,
          thumbnailUrl: `https://drive.google.com/thumbnail?id=${row.drive_file_id}&sz=w500`,
          viewUrl: `https://drive.google.com/uc?export=view&id=${row.drive_file_id}`,
        }));
      }

      const labels = PERIOD_LABELS[set.period] || { periodTitle: set.period, subtitle: '' };

      return {
        period: set.period,
        periodTitle: labels.periodTitle,
        subtitle: labels.subtitle,
        items,
      };
    })
  );

  return c.json({ flashbacks: result });
});
