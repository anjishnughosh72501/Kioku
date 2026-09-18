// routes/friends.js
// Authenticated two-way friend request flow and album invitations with rate limiting and persistence.

const express = require('express');
const crypto = require('crypto');
const jwt = require('jsonwebtoken');
const rateLimit = require('express-rate-limit');
const { nanoid } = require('nanoid');
const db = require('../db');
const { HttpError } = require('../middleware/errorHandler');

const router = express.Router();

const FRIENDS_LIMITER = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 100,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many friend requests, please try again later' },
});

const TOKEN_LIMITER = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 60,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many authentication attempts, please try again later' },
});

function hashSecret(secret) {
  return crypto.createHash('sha256').update(String(secret).trim()).digest('hex');
}

// Middleware: verifies that the caller owns the friend code claimed in the request
function requireFriendAuth(req, res, next) {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Missing or malformed Authorization header' });
  }

  const token = authHeader.split(' ')[1];
  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET, { algorithms: ['HS256'] });
    if (!decoded || !decoded.friendCode) {
      return res.status(401).json({ error: 'Invalid token payload' });
    }
    req.friend = { friendCode: decoded.friendCode };
    next();
  } catch (err) {
    return res.status(401).json({ error: 'Invalid or expired authorization token' });
  }
}

// 0. Issue / refresh authorization token for a friend code using device secret
router.post('/token', TOKEN_LIMITER, (req, res, next) => {
  try {
    const { friendCode, secret } = req.body;
    if (!friendCode || !secret) {
      throw new HttpError(400, 'friendCode and secret are required');
    }

    const cleanCode = String(friendCode).trim().toUpperCase();
    if (cleanCode.length < 3 || cleanCode.length > 32) {
      throw new HttpError(400, 'friendCode must be between 3 and 32 characters');
    }

    const cleanSecret = String(secret).trim();
    if (cleanSecret.length < 16) {
      throw new HttpError(400, 'secret must be at least 16 characters');
    }

    const secretHash = hashSecret(cleanSecret);
    const existing = db.prepare(`SELECT * FROM friend_accounts WHERE friend_code = ?`).get(cleanCode);

    if (!existing) {
      db.prepare(
        `INSERT INTO friend_accounts (friend_code, secret_hash, created_at) VALUES (?, ?, ?)`
      ).run(cleanCode, secretHash, Date.now());
    } else if (existing.secret_hash !== secretHash) {
      throw new HttpError(401, 'Invalid device credentials for this friend code');
    }

    const token = jwt.sign(
      { friendCode: cleanCode },
      process.env.JWT_SECRET,
      { expiresIn: '90d' }
    );

    res.json({ token, friendCode: cleanCode });
  } catch (err) {
    next(err);
  }
});

// 1. Send friend request
router.post('/request', FRIENDS_LIMITER, requireFriendAuth, (req, res, next) => {
  try {
    const { toCode, fromName } = req.body;
    const fromCode = req.friend.friendCode;
    if (!toCode) {
      throw new HttpError(400, 'toCode is required');
    }

    const cleanFrom = fromCode;
    const cleanTo = String(toCode).trim().toUpperCase();

    if (cleanFrom === cleanTo) {
      throw new HttpError(400, 'Cannot send a friend request to yourself');
    }

    // Check if an active pending request already exists
    const existing = db.prepare(
      `SELECT id, status FROM friend_requests WHERE from_code = ? AND to_code = ? AND status = 'pending'`
    ).get(cleanFrom, cleanTo);

    if (existing) {
      return res.json({ id: existing.id, status: 'pending', alreadySent: true });
    }

    const id = nanoid(16);
    const now = Date.now();

    db.prepare(
      `INSERT INTO friend_requests (id, from_code, to_code, from_name, status, created_at, updated_at)
       VALUES (?, ?, ?, ?, 'pending', ?, ?)`
    ).run(id, cleanFrom, cleanTo, fromName ? String(fromName).trim() : null, now, now);

    res.json({ id, status: 'pending', alreadySent: false });
  } catch (err) {
    next(err);
  }
});

// 2. Poll incoming pending requests AND accepted requests for a user (bidirectional sync)
router.get('/requests/:myCode', FRIENDS_LIMITER, requireFriendAuth, (req, res, next) => {
  try {
    const { myCode } = req.params;
    if (!myCode) {
      throw new HttpError(400, 'myCode is required');
    }

    const cleanCode = String(myCode).trim().toUpperCase();
    if (req.friend.friendCode !== cleanCode) {
      throw new HttpError(403, 'Forbidden: cannot access friend requests for another code');
    }

    // Requests addressed TO me that are pending
    const incomingRows = db.prepare(
      `SELECT id, from_code AS fromCode, to_code AS toCode, from_name AS fromName, created_at AS createdAt
       FROM friend_requests
       WHERE to_code = ? AND status = 'pending'
       ORDER BY created_at DESC`
    ).all(cleanCode);

    // Requests sent BY me that were accepted (so I can add them to my friends list too!)
    const acceptedRows = db.prepare(
      `SELECT id, from_code AS fromCode, to_code AS toCode, from_name AS fromName, updated_at AS updatedAt
       FROM friend_requests
       WHERE from_code = ? AND status = 'accepted'
       ORDER BY updated_at DESC`
    ).all(cleanCode);

    res.json({
      requests: incomingRows,
      accepted: acceptedRows,
    });
  } catch (err) {
    next(err);
  }
});

// 3. Acknowledge an accepted request (mark synced)
router.post('/ack', FRIENDS_LIMITER, requireFriendAuth, (req, res, next) => {
  try {
    const { requestId } = req.body;
    if (!requestId) {
      throw new HttpError(400, 'requestId is required');
    }

    const cleanCode = req.friend.friendCode;
    const now = Date.now();
    db.prepare(
      `UPDATE friend_requests SET status = 'synced', updated_at = ? WHERE id = ? AND from_code = ?`
    ).run(now, requestId, cleanCode);

    res.json({ ok: true });
  } catch (err) {
    next(err);
  }
});

// 4. Accept a friend request
router.post('/accept', FRIENDS_LIMITER, requireFriendAuth, (req, res, next) => {
  try {
    const { requestId } = req.body;
    if (!requestId) {
      throw new HttpError(400, 'requestId is required');
    }

    const cleanCode = req.friend.friendCode;
    const request = db.prepare(`SELECT * FROM friend_requests WHERE id = ?`).get(requestId);

    if (!request) {
      throw new HttpError(404, 'Friend request not found');
    }

    if (request.to_code !== cleanCode) {
      throw new HttpError(403, 'Unauthorized to accept this request');
    }

    const now = Date.now();
    db.prepare(
      `UPDATE friend_requests SET status = 'accepted', updated_at = ? WHERE id = ?`
    ).run(now, requestId);

    res.json({
      ok: true,
      fromCode: request.from_code,
      fromName: request.from_name,
    });
  } catch (err) {
    next(err);
  }
});

// 5. Decline a friend request
router.post('/decline', FRIENDS_LIMITER, requireFriendAuth, (req, res, next) => {
  try {
    const { requestId } = req.body;
    if (!requestId) {
      throw new HttpError(400, 'requestId is required');
    }

    const cleanCode = req.friend.friendCode;
    const request = db.prepare(`SELECT * FROM friend_requests WHERE id = ?`).get(requestId);

    if (!request) {
      throw new HttpError(404, 'Friend request not found');
    }

    if (request.to_code !== cleanCode) {
      throw new HttpError(403, 'Unauthorized to decline this request');
    }

    const now = Date.now();
    db.prepare(
      `UPDATE friend_requests SET status = 'declined', updated_at = ? WHERE id = ?`
    ).run(now, requestId);

    res.json({ ok: true });
  } catch (err) {
    next(err);
  }
});

// --- ALBUM INVITATIONS & CROSS-ACCOUNT SYNC ---

// 6. Send in-app album invite to a friend
router.post('/albums/invite', FRIENDS_LIMITER, requireFriendAuth, (req, res, next) => {
  try {
    const { albumId, albumName, toCode, fromName, claimToken, inviterPubKey } = req.body;
    const fromCode = req.friend.friendCode;
    if (!albumId || !toCode) {
      throw new HttpError(400, 'albumId and toCode are required');
    }

    const cleanFrom = fromCode;
    const cleanTo = String(toCode).trim().toUpperCase();

    if (cleanFrom === cleanTo) {
      throw new HttpError(400, 'Cannot invite yourself to an album');
    }

    const id = nanoid(16);
    const now = Date.now();

    db.prepare(
      `INSERT INTO album_invites (id, album_id, album_name, from_code, to_code, from_name, claim_token, inviter_pub_key, status, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'pending', ?, ?)`
    ).run(
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
    );

    res.json({ id, status: 'pending' });
  } catch (err) {
    next(err);
  }
});

// 7. Poll incoming album invites for a user
router.get('/albums/invites/:myCode', FRIENDS_LIMITER, requireFriendAuth, (req, res, next) => {
  try {
    const { myCode } = req.params;
    if (!myCode) {
      throw new HttpError(400, 'myCode is required');
    }

    const cleanCode = String(myCode).trim().toUpperCase();
    if (req.friend.friendCode !== cleanCode) {
      throw new HttpError(403, 'Forbidden: cannot access album invites for another code');
    }

    const rows = db.prepare(
      `SELECT id, album_id AS albumId, album_name AS albumName, from_code AS fromCode,
              to_code AS toCode, from_name AS fromName, claim_token AS claimToken,
              inviter_pub_key AS inviterPubKey, created_at AS createdAt
       FROM album_invites
       WHERE to_code = ? AND status = 'pending'
       ORDER BY created_at DESC`
    ).all(cleanCode);

    res.json({ invites: rows });
  } catch (err) {
    next(err);
  }
});

// 8. Accept an album invite
router.post('/albums/accept', FRIENDS_LIMITER, requireFriendAuth, (req, res, next) => {
  try {
    const { inviteId } = req.body;
    if (!inviteId) {
      throw new HttpError(400, 'inviteId is required');
    }

    const cleanCode = req.friend.friendCode;
    const invite = db.prepare(`SELECT * FROM album_invites WHERE id = ?`).get(inviteId);

    if (!invite) {
      throw new HttpError(404, 'Album invite not found');
    }

    if (invite.to_code !== cleanCode) {
      throw new HttpError(403, 'Unauthorized to accept this album invite');
    }

    const now = Date.now();
    db.prepare(
      `UPDATE album_invites SET status = 'accepted', updated_at = ? WHERE id = ?`
    ).run(now, inviteId);

    res.json({
      ok: true,
      albumId: invite.album_id,
      albumName: invite.album_name,
      fromCode: invite.from_code,
      fromName: invite.from_name,
      claimToken: invite.claim_token,
      inviterPubKey: invite.inviter_pub_key,
    });
  } catch (err) {
    next(err);
  }
});

// 9. Decline an album invite
router.post('/albums/decline', FRIENDS_LIMITER, requireFriendAuth, (req, res, next) => {
  try {
    const { inviteId } = req.body;
    if (!inviteId) {
      throw new HttpError(400, 'inviteId is required');
    }

    const cleanCode = req.friend.friendCode;
    const invite = db.prepare(`SELECT * FROM album_invites WHERE id = ?`).get(inviteId);

    if (!invite) {
      throw new HttpError(404, 'Album invite not found');
    }

    if (invite.to_code !== cleanCode) {
      throw new HttpError(403, 'Unauthorized to decline this album invite');
    }

    const now = Date.now();
    db.prepare(
      `UPDATE album_invites SET status = 'declined', updated_at = ? WHERE id = ?`
    ).run(now, inviteId);

    res.json({ ok: true });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
