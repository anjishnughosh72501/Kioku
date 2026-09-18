// routes/claim.js
// Short-lived single-use claim tokens for secure device-keypair collection key exchange.
// NO raw collection keys or master keys ever pass through here.

const express = require('express');
const rateLimit = require('express-rate-limit');
const { nanoid } = require('nanoid');
const db = require('../db');
const { HttpError } = require('../middleware/errorHandler');

const router = express.Router();

const CLAIM_LIMITER = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 30,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many claim requests, please try again later' },
});

// 1. Inviter creates a short-lived, single-use claim token
router.post('/request', CLAIM_LIMITER, (req, res, next) => {
  try {
    const { albumId, inviterPubKey } = req.body;
    if (!albumId || !inviterPubKey) {
      throw new HttpError(400, 'albumId and inviterPubKey are required');
    }

    const token = nanoid(24);
    const expiresAt = Date.now() + 10 * 60 * 1000; // 10 minutes TTL

    db.prepare(
      `INSERT INTO claim_tokens (token, album_id, inviter_pub_key, expires_at, used)
       VALUES (?, ?, ?, ?, 0)`
    ).run(token, albumId, inviterPubKey, expiresAt);

    res.json({ claimToken: token, expiresAt });
  } catch (err) {
    next(err);
  }
});

// 2. Joining device redeems claim token and registers its recipient public key
router.post('/redeem', CLAIM_LIMITER, (req, res, next) => {
  try {
    const { claimToken, recipientPubKey } = req.body;
    if (!claimToken) {
      throw new HttpError(400, 'claimToken is required');
    }

    const claim = db.prepare(`SELECT * FROM claim_tokens WHERE token = ?`).get(claimToken);
    if (!claim) {
      throw new HttpError(404, 'Claim token not found');
    }

    if (claim.used === 1) {
      throw new HttpError(410, 'Claim token has already been used');
    }

    if (Date.now() > claim.expires_at) {
      throw new HttpError(410, 'Claim token has expired');
    }

    // Mark as used
    db.prepare(
      `UPDATE claim_tokens SET used = 1, recipient_pub_key = ? WHERE token = ?`
    ).run(recipientPubKey || null, claimToken);

    res.json({
      albumId: claim.album_id,
      inviterPubKey: claim.inviter_pub_key,
    });
  } catch (err) {
    next(err);
  }
});

// 3. Inviter posts sealed collection key (sealed with recipient's public key using crypto_box_seal)
router.post('/seal', CLAIM_LIMITER, (req, res, next) => {
  try {
    const { claimToken, sealedKey } = req.body;
    if (!claimToken || !sealedKey) {
      throw new HttpError(400, 'claimToken and sealedKey are required');
    }

    const claim = db.prepare(`SELECT * FROM claim_tokens WHERE token = ?`).get(claimToken);
    if (!claim) {
      throw new HttpError(404, 'Claim token not found');
    }

    db.prepare(`UPDATE claim_tokens SET sealed_key = ? WHERE token = ?`).run(sealedKey, claimToken);

    res.json({ ok: true });
  } catch (err) {
    next(err);
  }
});

// 4. Joining device polls/retrieves sealed collection key
router.get('/sealed/:claimToken', CLAIM_LIMITER, (req, res, next) => {
  try {
    const { claimToken } = req.params;
    const claim = db.prepare(`SELECT * FROM claim_tokens WHERE token = ?`).get(claimToken);
    if (!claim) {
      throw new HttpError(404, 'Claim token not found');
    }

    if (Date.now() > claim.expires_at + 60 * 60 * 1000) {
      throw new HttpError(410, 'Claim record expired');
    }

    res.json({
      albumId: claim.album_id,
      sealedKey: claim.sealed_key || null,
      recipientPubKey: claim.recipient_pub_key || null,
    });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
