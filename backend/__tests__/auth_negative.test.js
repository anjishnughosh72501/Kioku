const request = require('supertest');
const jwt = require('jsonwebtoken');
process.env.JWT_SECRET = 'test_secret_for_auth_negative_suite_12345';

const { initDB } = require('../db');
const { createApp } = require('../server');
const db = require('../db');

let app;

beforeAll(async () => {
  await initDB();
  app = createApp();
});

describe('P2-9: Negative Authentication & Authorization Security Tests', () => {
  const userA = 'USER_AAA';
  const userB = 'USER_BBB';
  const secretA = 'secret_pass_a_123';
  const secretB = 'secret_pass_b_456';
  let tokenA;
  let tokenB;

  beforeAll(async () => {
    // Mint valid tokens for userA and userB
    const resA = await request(app)
      .post('/friends/token')
      .send({ friendCode: userA, secret: secretA });
    expect(resA.status).toBe(200);
    tokenA = resA.body.token;

    const resB = await request(app)
      .post('/friends/token')
      .send({ friendCode: userB, secret: secretB });
    expect(resB.status).toBe(200);
    tokenB = resB.body.token;
  });

  describe('JWT Token Validation Negative Paths', () => {
    test('Rejects request with missing Authorization header', async () => {
      const res = await request(app)
        .get('/friends/requests/' + userA);
      expect(res.status).toBe(401);
      expect(res.body.error).toMatch(/Missing or malformed Authorization header/i);
    });

    test('Rejects request with malformed Authorization header (no Bearer prefix)', async () => {
      const res = await request(app)
        .get('/friends/requests/' + userA)
        .set('Authorization', 'Basic ' + tokenA);
      expect(res.status).toBe(401);
      expect(res.body.error).toMatch(/Missing or malformed Authorization header/i);
    });

    test('Rejects request with invalid/garbage JWT format', async () => {
      const res = await request(app)
        .get('/friends/requests/' + userA)
        .set('Authorization', 'Bearer not-a-valid-jwt-token');
      expect(res.status).toBe(401);
      expect(res.body.error).toMatch(/Invalid or expired authorization token/i);
    });

    test('Rejects request with tampered JWT signature (signed by untrusted key)', async () => {
      const bogusToken = jwt.sign({ friendCode: userA }, 'malicious_attacker_key_67890');
      const res = await request(app)
        .get('/friends/requests/' + userA)
        .set('Authorization', 'Bearer ' + bogusToken);
      expect(res.status).toBe(401);
      expect(res.body.error).toMatch(/Invalid or expired authorization token/i);
    });

    test('Rejects request with expired JWT token', async () => {
      const expiredToken = jwt.sign(
        { friendCode: userA, exp: Math.floor(Date.now() / 1000) - 60 },
        process.env.JWT_SECRET
      );
      const res = await request(app)
        .get('/friends/requests/' + userA)
        .set('Authorization', 'Bearer ' + expiredToken);
      expect(res.status).toBe(401);
      expect(res.body.error).toMatch(/Invalid or expired authorization token/i);
    });

    test('Rejects token without friendCode payload claim', async () => {
      const invalidPayloadToken = jwt.sign({ sub: 'anonymous' }, process.env.JWT_SECRET);
      const res = await request(app)
        .get('/friends/requests/' + userA)
        .set('Authorization', 'Bearer ' + invalidPayloadToken);
      expect(res.status).toBe(401);
      expect(res.body.error).toMatch(/Invalid token payload/i);
    });
  });

  describe('Cross-User IDOR Access Control Enforcements', () => {
    test('User B cannot inspect User A friend requests', async () => {
      const res = await request(app)
        .get('/friends/requests/' + userA)
        .set('Authorization', 'Bearer ' + tokenB);
      expect(res.status).toBe(403);
      expect(res.body.error).toMatch(/Forbidden: cannot access friend requests/i);
    });

    test('User B cannot inspect User A album invites', async () => {
      const res = await request(app)
        .get('/friends/albums/invites/' + userA)
        .set('Authorization', 'Bearer ' + tokenB);
      expect(res.status).toBe(403);
      expect(res.body.error).toMatch(/Forbidden: cannot access album invites/i);
    });

    test('User A cannot spoof fromCode when creating friend request', async () => {
      const res = await request(app)
        .post('/friends/request')
        .set('Authorization', 'Bearer ' + tokenA)
        .send({ toCode: userB, fromName: 'Attacker' });

      expect(res.status).toBe(200);
      // Ensure backend forced from_code to userA regardless of any spoof attempts
      const record = db.prepare('SELECT * FROM friend_requests WHERE id = ?').get(res.body.id);
      expect(record.from_code).toBe(userA);
    });
  });

  describe('Claim Token Negative Security Paths', () => {
    test('Fails on non-existent claim token', async () => {
      const res = await request(app)
        .post('/claim/redeem')
        .send({ claimToken: 'nonexistent_token_12345678', recipientPubKey: 'pk_test' });
      expect(res.status).toBe(404);
      expect(res.body.error).toMatch(/Claim token not found/i);
    });

    test('Fails on expired claim token', async () => {
      const token = 'expired_token_test_123';
      db.prepare(
        'INSERT OR REPLACE INTO claim_tokens (token, album_id, inviter_pub_key, expires_at, used) VALUES (?, ?, ?, ?, 0)'
      ).run(token, 'album-1', 'inviter_pk', Date.now() - 10000);

      const res = await request(app)
        .post('/claim/redeem')
        .send({ claimToken: token, recipientPubKey: 'pk_test' });
      expect(res.status).toBe(410);
      expect(res.body.error).toMatch(/Claim token has expired/i);
    });

    test('Fails on replayed/already used claim token', async () => {
      const token = 'used_token_test_123';
      db.prepare(
        'INSERT OR REPLACE INTO claim_tokens (token, album_id, inviter_pub_key, expires_at, used) VALUES (?, ?, ?, ?, 1)'
      ).run(token, 'album-1', 'inviter_pk', Date.now() + 60000);

      const res = await request(app)
        .post('/claim/redeem')
        .send({ claimToken: token, recipientPubKey: 'pk_test' });
      expect(res.status).toBe(410);
      expect(res.body.error).toMatch(/Claim token has already been used/i);
    });
  });
});
