// routes/media.js
const express = require('express');
const multer = require('multer');
const { nanoid } = require('nanoid');
const db = require('../db');
const requireAuth = require('../middleware/requireAuth');
const { HttpError } = require('../middleware/errorHandler');
const { uploadFile } = require('../services/driveService');

const router = express.Router();
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 200 * 1024 * 1024 },
});

const ALLOWED_MEDIA_MIME = /^(image\/|video\/)/;
const MAX_CAPTION_LENGTH = 1000;
const MAX_PAGE_SIZE = 100;

// Upload a photo or video
router.post('/upload', requireAuth, upload.single('file'), async (req, res, next) => {
  try {
    const { groupId, userId } = req.user;
    const { caption = null, takenAt = null, type = 'photo' } = req.body;

    if (!req.file) throw new HttpError(400, 'file is required');

    if (type !== 'photo' && type !== 'video') {
      throw new HttpError(400, "type must be 'photo' or 'video'");
    }
    if (!ALLOWED_MEDIA_MIME.test(req.file.mimetype || '')) {
      throw new HttpError(400, 'Only image/video files are allowed');
    }
    if (caption && caption.length > MAX_CAPTION_LENGTH) {
      throw new HttpError(400, `caption must be ${MAX_CAPTION_LENGTH} characters or fewer`);
    }
    if (takenAt && Number.isNaN(Date.parse(takenAt))) {
      throw new HttpError(400, 'takenAt must be a valid ISO date string');
    }

    const group = db.prepare(`SELECT * FROM groups WHERE id = ?`).get(groupId);
    if (!group || !group.drive_folder_id) {
      throw new HttpError(404, 'Group not found');
    }

    const safeName = req.file.originalname ? req.file.originalname.replace(/[^\w.\- ]+/g, '_') : 'upload';
    const filename = `${Date.now()}_${safeName}`;

    const { fileId } = await uploadFile({
      buffer: req.file.buffer,
      filename,
      mimeType: req.file.mimetype,
      folderId: group.drive_folder_id,
    });

    const mediaId = nanoid();
    db.prepare(
      `INSERT INTO media (id, drive_file_id, group_id, uploader_id, type, caption, taken_at)
       VALUES (?, ?, ?, ?, ?, ?, ?)`
    ).run(
      mediaId,
      fileId,
      groupId,
      userId,
      type,
      caption || null,
      takenAt || new Date().toISOString()
    );

    res.json({ mediaId, driveFileId: fileId });
  } catch (err) {
    next(err);
  }
});

// Feed - sorted by day (default) or by uploader
router.get('/feed', requireAuth, (req, res, next) => {
  try {
    const { groupId } = req.user;
    const { sort = 'day', uploaderId } = req.query;
    const page = Math.max(1, parseInt(req.query.page, 10) || 1);
    const pageSize = Math.min(MAX_PAGE_SIZE, Math.max(1, parseInt(req.query.pageSize, 10) || 30));

    if (sort !== 'day' && sort !== 'uploader') {
      throw new HttpError(400, "sort must be 'day' or 'uploader'");
    }

    let query = `
      SELECT media.*, users.name AS uploader_name
      FROM media
      JOIN users ON users.id = media.uploader_id
      WHERE media.group_id = ?
    `;
    const params = [groupId];

    if (uploaderId) {
      query += ` AND media.uploader_id = ?`;
      params.push(uploaderId);
    }

    const orderBy = sort === 'uploader' ? 'media.uploader_id, media.taken_at' : 'media.taken_at';
    query += ` ORDER BY ${orderBy} DESC`;
    query += ` LIMIT ? OFFSET ?`;
    params.push(pageSize, (page - 1) * pageSize);

    const rows = db.prepare(query).all(...params);

    const items = rows.map((row) => ({
      id: row.id,
      type: row.type,
      caption: row.caption,
      takenAt: row.taken_at,
      uploaderName: row.uploader_name,
      thumbnailUrl: `https://drive.google.com/thumbnail?id=${row.drive_file_id}&sz=w500`,
      viewUrl: `https://drive.google.com/uc?export=view&id=${row.drive_file_id}`,
    }));

    res.json({ items });
  } catch (err) {
    next(err);
  }
});

// All uploaders in the group, for the "by person" filter row
router.get('/uploaders', requireAuth, (req, res, next) => {
  try {
    const { groupId } = req.user;
    const rows = db
      .prepare(`SELECT DISTINCT users.id, users.name FROM users WHERE users.group_id = ?`)
      .all(groupId);
    res.json({ uploaders: rows });
  } catch (err) {
    next(err);
  }
});

module.exports = router;