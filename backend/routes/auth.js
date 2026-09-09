// routes/auth.js
// Lightweight invite-code auth for friends. No Google login for them at all.

const express = require('express');
const jwt = require('jsonwebtoken');
const rateLimit = require('express-rate-limit');
const { nanoid } = require('nanoid');
const db = require('../db');
const requireAuth = require('../middleware/requireAuth');
const { HttpError } = require('../middleware/errorHandler');
const { ensureGroupFolder } = require('../services/driveService');

const router = express.Router();

const MAX_NAME_LENGTH = 60;
const MAX_GROUP_NAME_LENGTH = 80;

const JOIN_LIMITER = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 20,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many sign-in attempts, please try again later' },
});

const GROUP_LIMITER = rateLimit({
  windowMs: 60 * 60 * 1000,
  limit: 5,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many group creations, please try again later' },
});

function cleanName(raw, field, maxLength) {
  const name = (raw ?? '').toString().trim().replace(/[\u0000-\u001f\u007f]/g, '');
  if (!name) throw new HttpError(400, `${field} is required`);
  if (name.length > maxLength) {
    throw new HttpError(400, `${field} must be ${maxLength} characters or fewer`);
  }
  return name;
}

// Create a brand new friend group (you'd do this once for your group)
router.post('/groups', GROUP_LIMITER, async (req, res, next) => {
  try {
    const groupName = cleanName(req.body.groupName, 'groupName', MAX_GROUP_NAME_LENGTH);

    const id = nanoid();
    const inviteCode = nanoid(8).toUpperCase();
    const driveFolderId = await ensureGroupFolder(groupName);

    db.prepare(
      `INSERT INTO groups (id, name, invite_code, drive_folder_id) VALUES (?, ?, ?, ?)`
    ).run(id, groupName, inviteCode, driveFolderId);

    res.json({ groupId: id, inviteCode });
  } catch (err) {
    next(err);
  }
});

// A friend joins using the invite code + picks a display name
router.post('/join', JOIN_LIMITER, (req, res, next) => {
  try {
    const inviteCode = (req.body.inviteCode ?? '').toString().trim().toUpperCase();
    const name = cleanName(req.body.name, 'name', MAX_NAME_LENGTH);

    if (!inviteCode) {
      throw new HttpError(400, 'inviteCode is required');
    }

    const group = db.prepare(`SELECT * FROM groups WHERE invite_code = ?`).get(inviteCode);
    if (!group) throw new HttpError(404, 'Invalid invite code');

    const userId = nanoid();
    db.prepare(`INSERT INTO users (id, name, group_id) VALUES (?, ?, ?)`).run(
      userId,
      name,
      group.id
    );

    const token = jwt.sign(
      { userId, groupId: group.id, name },
      process.env.JWT_SECRET,
      { expiresIn: '365d' }
    );

    res.json({ token, userId, groupId: group.id, groupName: group.name });
  } catch (err) {
    next(err);
  }
});

// Current user + circle info (drives the app's "me" state / profile screen)
router.get('/me', requireAuth, (req, res, next) => {
  try {
    const { userId, groupId, name } = req.user;
    const group = db.prepare(`SELECT * FROM groups WHERE id = ?`).get(groupId);
    if (!group) throw new HttpError(404, 'Group not found');

    res.json({
      userId,
      name,
      groupId: group.id,
      groupName: group.name,
      inviteCode: group.invite_code,
      role: 'member',
    });
  } catch (err) {
    next(err);
  }
});

module.exports = router;