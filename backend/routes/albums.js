// routes/albums.js
// Server-side album model and membership management for Kioku local backend.

const express = require('express');
const { nanoid } = require('nanoid');
const db = require('../db');
const { HttpError } = require('../middleware/errorHandler');
const { requireFriendAuth } = require('./friends');

const router = express.Router();

// 1. Create a shareable album and register the caller as the active owner
router.post('/', requireFriendAuth, (req, res, next) => {
  try {
    const userCode = req.friend.friendCode;
    const body = req.body || {};
    const title = body.title || body.name;
    if (!title || typeof title !== 'string' || !title.trim()) {
      throw new HttpError(400, 'title or name is required');
    }

    const cleanTitle = title.trim();
    const albumId =
      body.id && String(body.id).trim().length > 0
        ? String(body.id).trim()
        : `album_${nanoid(16)}`;
    const now = Date.now();
    const resolvedStorage = body.storageType || 'local';

    const existing = db.prepare(`SELECT * FROM albums WHERE id = ?`).get(albumId);
    if (existing) {
      const member = db.prepare(
        `SELECT * FROM album_members WHERE album_id = ? AND user_id = ? AND status = 'active'`
      ).get(albumId, userCode);
      if (member) {
        return res.json({
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
      throw new HttpError(409, 'Album ID collision');
    }

    db.transaction(() => {
      db.prepare(
        `INSERT INTO albums (id, owner_user_id, title, storage_type, storage_reference, current_epoch, created_at, updated_at)
         VALUES (?, ?, ?, ?, ?, 1, ?, ?)`
      ).run(albumId, userCode, cleanTitle, resolvedStorage, body.storageReference || null, now, now);
      db.prepare(
        `INSERT INTO album_members (album_id, user_id, role, status, joined_at, updated_at)
         VALUES (?, ?, 'owner', 'active', ?, ?)`
      ).run(albumId, userCode, now, now);
    });

    res.status(201).json({
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
    });
  } catch (err) {
    next(err);
  }
});

// 2. Retrieve all active album memberships for the authenticated user
router.get('/', requireFriendAuth, (req, res, next) => {
  try {
    const userCode = req.friend.friendCode;
    const rows = db.prepare(
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
    ).all(userCode);

    res.json({ albums: rows || [] });
  } catch (err) {
    next(err);
  }
});

// 3. Get specific album details
router.get('/:albumId', requireFriendAuth, (req, res, next) => {
  try {
    const userCode = req.friend.friendCode;
    const albumId = req.params.albumId;
    const row = db.prepare(
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
         m.status
       FROM album_members m
       JOIN albums a ON a.id = m.album_id
       WHERE a.id = ? AND m.user_id = ? AND m.status = 'active'`
    ).get(albumId, userCode);

    if (!row) {
      throw new HttpError(404, 'Album not found or access denied');
    }
    res.json({ album: row });
  } catch (err) {
    next(err);
  }
});

// 4. Delete an album
router.delete('/:albumId', requireFriendAuth, (req, res, next) => {
  try {
    const userCode = req.friend.friendCode;
    const albumId = req.params.albumId;
    const album = db.prepare(`SELECT * FROM albums WHERE id = ?`).get(albumId);
    if (!album) {
      throw new HttpError(404, 'Album not found');
    }
    if (album.owner_user_id !== userCode) {
      throw new HttpError(403, 'Only the album owner can delete this album');
    }
    db.transaction(() => {
      db.prepare(`DELETE FROM album_members WHERE album_id = ?`).run(albumId);
      db.prepare(`DELETE FROM albums WHERE id = ?`).run(albumId);
    });
    res.json({ ok: true });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
