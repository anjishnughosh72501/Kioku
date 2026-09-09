const express = require('express');
const db = require('../db');
const requireAuth = require('../middleware/requireAuth');

const router = express.Router();

const PERIOD_LABELS = {
  yearly: { periodTitle: '1 Year Ago Today', subtitle: "From last year's album" },
  monthly: { periodTitle: "Last Month's Album", subtitle: 'From last month' },
  weekly: { periodTitle: 'A Passing Memory', subtitle: 'From this week' },
};

router.get('/', requireAuth, (req, res) => {
  const { groupId } = req.user;
  const today = new Date().toISOString().slice(0, 10);

  const sets = db
    .prepare(`SELECT * FROM flashbacks WHERE group_id = ? AND generated_for = ?`)
    .all(groupId, today);

  const result = sets.map((set) => {
    let mediaIds = [];
    try {
      const parsed = JSON.parse(set.media_ids);
      if (Array.isArray(parsed)) mediaIds = parsed.filter((id) => typeof id === 'string');
    } catch {
      // Corrupt media_ids - skip this set rather than failing the whole request
    }
    const placeholders = mediaIds.map(() => '?').join(',');
    const items = mediaIds.length
      ? db
          .prepare(
            `SELECT media.*, users.name AS uploader_name FROM media
             JOIN users ON users.id = media.uploader_id
             WHERE media.id IN (${placeholders})`
          )
          .all(...mediaIds)
      : [];

    const labels = PERIOD_LABELS[set.period] || { periodTitle: set.period, subtitle: '' };

    return {
      period: set.period,
      periodTitle: labels.periodTitle,
      subtitle: labels.subtitle,
      items: items.map((row) => ({
        id: row.id,
        type: row.type,
        caption: row.caption,
        takenAt: row.taken_at,
        uploaderName: row.uploader_name,
        thumbnailUrl: `https://drive.google.com/thumbnail?id=${row.drive_file_id}&sz=w500`,
        viewUrl: `https://drive.google.com/uc?export=view&id=${row.drive_file_id}`,
      })),
    };
  });

  res.json({ flashbacks: result });
});

module.exports = router;
