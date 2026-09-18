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

function generateInviteCode() {
  const chars = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
  const bytes = crypto.randomBytes(6);
  let code = '';
  for (let i = 0; i < 6; i++) {
    code += chars[bytes[i] % chars.length];
  }
  return code;
}

function resolveInviteDetails(rawCode) {
  if (!rawCode) return { status: 'invalid' };
  const cleanCode = String(rawCode).trim().toUpperCase();
  const invite = db.prepare(`SELECT * FROM invites WHERE invite_code = ?`).get(cleanCode);
  if (!invite) {
    return { status: 'invalid' };
  }

  const now = Date.now();
  if (invite.status === 'valid' && now > invite.expires_at) {
    db.prepare(`UPDATE invites SET status = 'expired' WHERE id = ?`).run(invite.id);
    return { status: 'expired' };
  }

  if (invite.status !== 'valid') {
    return { status: invite.status };
  }

  const account = db.prepare(`SELECT username FROM friend_accounts WHERE friend_code = ?`).get(invite.created_by);
  return {
    username: (account && account.username) || invite.from_name || 'Friend',
    friendCode: invite.created_by,
    status: 'valid',
    expiresAt: invite.expires_at,
  };
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
    const { friendCode, secret, username } = req.body;
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
        `INSERT INTO friend_accounts (friend_code, secret_hash, username, created_at) VALUES (?, ?, ?, ?)`
      ).run(cleanCode, secretHash, username ? String(username).trim() : null, Date.now());
    } else {
      if (existing.secret_hash !== secretHash) {
        throw new HttpError(401, 'Invalid device credentials for this friend code');
      }
      if (username) {
        db.prepare(`UPDATE friend_accounts SET username = ? WHERE friend_code = ?`).run(String(username).trim(), cleanCode);
      }
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

    // Normalized bidirectional friendship insertion
    const u1 = cleanCode < request.from_code ? cleanCode : request.from_code;
    const u2 = cleanCode < request.from_code ? request.from_code : cleanCode;
    db.prepare(`INSERT OR IGNORE INTO friends (user_a, user_b, created_at) VALUES (?, ?, ?)`).run(u1, u2, now);

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

// 5a. Cancel a sent friend request (caller must be sender)
router.post('/cancel', FRIENDS_LIMITER, requireFriendAuth, (req, res, next) => {
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

    if (request.from_code !== cleanCode) {
      throw new HttpError(403, 'Unauthorized to cancel this request');
    }

    const now = Date.now();
    db.prepare(
      `UPDATE friend_requests SET status = 'cancelled', updated_at = ? WHERE id = ?`
    ).run(now, requestId);

    res.json({ ok: true });
  } catch (err) {
    next(err);
  }
});

// 5b. Resend an expired or cancelled friend request
router.post('/resend', FRIENDS_LIMITER, requireFriendAuth, (req, res, next) => {
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

    if (request.from_code !== cleanCode) {
      throw new HttpError(403, 'Unauthorized to resend this request');
    }

    const now = Date.now();
    db.prepare(
      `UPDATE friend_requests SET status = 'pending', created_at = ?, updated_at = ? WHERE id = ?`
    ).run(now, now, requestId);

    res.json({ ok: true });
  } catch (err) {
    next(err);
  }
});

// 5c. Remove a friend relationship
router.post('/remove', FRIENDS_LIMITER, requireFriendAuth, (req, res, next) => {
  try {
    const { friendCode } = req.body;
    if (!friendCode) {
      throw new HttpError(400, 'friendCode is required');
    }

    const cleanCode = req.friend.friendCode;
    const otherCode = String(friendCode).trim().toUpperCase();
    const u1 = cleanCode < otherCode ? cleanCode : otherCode;
    const u2 = cleanCode < otherCode ? otherCode : cleanCode;

    db.prepare(`DELETE FROM friends WHERE user_a = ? AND user_b = ?`).run(u1, u2);
    res.json({ ok: true });
  } catch (err) {
    next(err);
  }
});

// 5d. Get accepted friends list
router.get('/list/:myCode', FRIENDS_LIMITER, requireFriendAuth, (req, res, next) => {
  try {
    const { myCode } = req.params;
    const cleanCode = String(myCode).trim().toUpperCase();
    if (req.friend.friendCode !== cleanCode) {
      throw new HttpError(403, 'Forbidden: cannot access friend list for another code');
    }

    const rows = db.prepare(`
      SELECT CASE WHEN user_a = ? THEN user_b ELSE user_a END AS friendCode, created_at AS createdAt
      FROM friends
      WHERE user_a = ? OR user_b = ?
      ORDER BY created_at DESC
    `).all(cleanCode, cleanCode, cleanCode);

    const enriched = rows.map((r) => {
      const acc = db.prepare(`SELECT username FROM friend_accounts WHERE friend_code = ?`).get(r.friendCode);
      return {
        friendCode: r.friendCode,
        username: (acc && acc.username) || null,
        createdAt: r.createdAt,
      };
    });

    res.json({ friends: enriched });
  } catch (err) {
    next(err);
  }
});

// 5e. Get sent friend requests (pending and expired)
router.get('/sent/:myCode', FRIENDS_LIMITER, requireFriendAuth, (req, res, next) => {
  try {
    const { myCode } = req.params;
    const cleanCode = String(myCode).trim().toUpperCase();
    if (req.friend.friendCode !== cleanCode) {
      throw new HttpError(403, 'Forbidden: cannot access sent requests for another code');
    }

    const rows = db.prepare(`
      SELECT id, from_code AS fromCode, to_code AS toCode, from_name AS fromName, status, created_at AS createdAt, updated_at AS updatedAt
      FROM friend_requests
      WHERE from_code = ?
      ORDER BY updated_at DESC
    `).all(cleanCode);

    const now = Date.now();
    const thirtyDaysMs = 30 * 24 * 60 * 60 * 1000;
    const enriched = rows.map((r) => {
      let currentStatus = r.status;
      if (currentStatus === 'pending' && (now - r.createdAt > thirtyDaysMs)) {
        currentStatus = 'expired';
        db.prepare(`UPDATE friend_requests SET status = 'expired' WHERE id = ?`).run(r.id);
      }
      const targetAcc = db.prepare(`SELECT username FROM friend_accounts WHERE friend_code = ?`).get(r.toCode);
      return {
        ...r,
        status: currentStatus,
        toName: (targetAcc && targetAcc.username) || null,
      };
    });

    res.json({ requests: enriched });
  } catch (err) {
    next(err);
  }
});

// 5f. Create short universal invite link
router.post('/invite', FRIENDS_LIMITER, requireFriendAuth, (req, res, next) => {
  try {
    const cleanCode = req.friend.friendCode;
    const { fromName } = req.body;
    const now = Date.now();
    const id = nanoid(16);
    const inviteCode = generateInviteCode();
    const expiresAt = now + (30 * 24 * 60 * 60 * 1000); // 30 days TTL

    const account = db.prepare(`SELECT username FROM friend_accounts WHERE friend_code = ?`).get(cleanCode);
    const effectiveName = fromName ? String(fromName).trim() : (account && account.username ? account.username : null);

    db.prepare(
      `INSERT INTO invites (id, invite_code, created_by, from_name, expires_at, status, created_at)
       VALUES (?, ?, ?, ?, ?, 'valid', ?)`
    ).run(id, inviteCode, cleanCode, effectiveName, expiresAt, now);

    res.json({
      code: inviteCode,
      url: `https://kioku.app/i/${inviteCode}`,
    });
  } catch (err) {
    next(err);
  }
});

// 5g. Resolve public invite code
router.get('/invite/:code', FRIENDS_LIMITER, (req, res, next) => {
  try {
    const { code } = req.params;
    const result = resolveInviteDetails(code);
    if (result.status === 'invalid') {
      return res.status(404).json(result);
    }
    res.json(result);
  } catch (err) {
    next(err);
  }
});

// 5h. Update profile username
router.post('/profile', FRIENDS_LIMITER, requireFriendAuth, (req, res, next) => {
  try {
    const { username } = req.body;
    if (!username) {
      throw new HttpError(400, 'username is required');
    }
    const cleanCode = req.friend.friendCode;
    const cleanName = String(username).trim();
    db.prepare(`UPDATE friend_accounts SET username = ? WHERE friend_code = ?`).run(cleanName, cleanCode);
    res.json({ ok: true, username: cleanName });
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
module.exports.resolveInviteDetails = resolveInviteDetails;
