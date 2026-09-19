const request = require('supertest');

process.env.JWT_SECRET = 'test-secret-key-1234567890-abcdefg';

const db = require('../db');
const { initDB } = db;
const { createApp } = require('../server');

let app;

beforeAll(async () => {
  await initDB();
  db.prepare(`DELETE FROM friends WHERE user_a LIKE 'KIOKU-%' OR user_b LIKE 'KIOKU-%'`).run();
  db.prepare(`DELETE FROM friend_requests WHERE from_code LIKE 'KIOKU-%' OR to_code LIKE 'KIOKU-%'`).run();
  db.prepare(`DELETE FROM friend_accounts WHERE friend_code LIKE 'KIOKU-%'`).run();
  app = createApp();
});

describe('Friend Request & Social Album API Routes (Hardened Auth)', () => {
  const userA = 'KIOKU-AAAA';
  const secretA = 'secure-device-secret-for-user-a-12345';
  let tokenA;

  const userB = 'KIOKU-BBBB';
  const secretB = 'secure-device-secret-for-user-b-12345';
  let tokenB;

  let createdRequestId;

  describe('POST /friends/token (Device Authentication)', () => {
    it('rejects registration with missing parameters', async () => {
      const res = await request(app).post('/friends/token').send({ friendCode: userA });
      expect(res.status).toBe(400);
    });

    it('rejects short secrets (< 16 chars)', async () => {
      const res = await request(app).post('/friends/token').send({ friendCode: userA, secret: 'short' });
      expect(res.status).toBe(400);
    });

    it('issues signed JWT for valid friendCode and secret', async () => {
      const resA = await request(app).post('/friends/token').send({ friendCode: userA, secret: secretA });
      expect(resA.status).toBe(200);
      expect(resA.body).toHaveProperty('token');
      expect(resA.body.friendCode).toBe(userA);
      tokenA = resA.body.token;

      const resB = await request(app).post('/friends/token').send({ friendCode: userB, secret: secretB });
      expect(resB.status).toBe(200);
      tokenB = resB.body.token;
    });

    it('rejects token request with incorrect secret for existing code', async () => {
      const res = await request(app).post('/friends/token').send({ friendCode: userA, secret: 'wrong-secret-12345678' });
      expect(res.status).toBe(401);
    });
  });

  describe('Authorization Enforcement on /friends/*', () => {
    it('rejects requests without Authorization header with 401', async () => {
      const res = await request(app).post('/friends/request').send({ toCode: userB });
      expect(res.status).toBe(401);
    });

    it('rejects requests with forged/tampered token with 401', async () => {
      const res = await request(app)
        .post('/friends/request')
        .set('Authorization', 'Bearer invalid-token')
        .send({ toCode: userB });
      expect(res.status).toBe(401);
    });

    it('prevents User A from polling User B requests (403 Forbidden)', async () => {
      const res = await request(app)
        .get(`/friends/requests/${userB}`)
        .set('Authorization', `Bearer ${tokenA}`);
      expect(res.status).toBe(403);
    });
  });

  describe('POST /friends/request', () => {
    it('rejects missing toCode parameter', async () => {
      const res = await request(app)
        .post('/friends/request')
        .set('Authorization', `Bearer ${tokenA}`)
        .send({});
      expect(res.status).toBe(400);
    });

    it('rejects sending friend request to oneself', async () => {
      const res = await request(app)
        .post('/friends/request')
        .set('Authorization', `Bearer ${tokenA}`)
        .send({ toCode: userA });
      expect(res.status).toBe(400);
    });

    it('creates a new friend request successfully using token identity', async () => {
      const res = await request(app)
        .post('/friends/request')
        .set('Authorization', `Bearer ${tokenA}`)
        .send({ toCode: userB, fromName: 'Alice' });

      expect(res.status).toBe(200);
      expect(res.body).toHaveProperty('id');
      expect(res.body.status).toBe('pending');
      expect(res.body.alreadySent).toBe(false);
      createdRequestId = res.body.id;
    });

    it('returns existing request if duplicate pending request is sent', async () => {
      const res = await request(app)
        .post('/friends/request')
        .set('Authorization', `Bearer ${tokenA}`)
        .send({ toCode: userB, fromName: 'Alice' });

      expect(res.status).toBe(200);
      expect(res.body.id).toBe(createdRequestId);
      expect(res.body.alreadySent).toBe(true);
    });
  });

  describe('GET /friends/requests/:myCode', () => {
    it('polls pending requests for recipient using their own token', async () => {
      const res = await request(app)
        .get(`/friends/requests/${userB}`)
        .set('Authorization', `Bearer ${tokenB}`);

      expect(res.status).toBe(200);
      expect(res.body).toHaveProperty('requests');
      expect(Array.isArray(res.body.requests)).toBe(true);
      const found = res.body.requests.find((r) => r.id === createdRequestId);
      expect(found).toBeDefined();
      expect(found.fromCode).toBe(userA);
      expect(found.fromName).toBe('Alice');
    });

    it('returns empty list for user with no requests', async () => {
      const userNone = 'KIOKU-NONE';
      const resToken = await request(app).post('/friends/token').send({
        friendCode: userNone,
        secret: 'secure-none-device-secret-12345',
      });
      const tokenNone = resToken.body.token;

      const res = await request(app)
        .get(`/friends/requests/${userNone}`)
        .set('Authorization', `Bearer ${tokenNone}`);

      expect(res.status).toBe(200);
      expect(res.body.requests).toEqual([]);
      expect(res.body.accepted).toEqual([]);
    });
  });

  describe('POST /friends/accept & Bidirectional Sync', () => {
    it('rejects accept when caller is not the intended recipient', async () => {
      const res = await request(app)
        .post('/friends/accept')
        .set('Authorization', `Bearer ${tokenA}`) // User A trying to accept request addressed to User B
        .send({ requestId: createdRequestId });
      expect(res.status).toBe(403);
    });

    it('accepts the friend request successfully with recipient token', async () => {
      const res = await request(app)
        .post('/friends/accept')
        .set('Authorization', `Bearer ${tokenB}`)
        .send({ requestId: createdRequestId });

      expect(res.status).toBe(200);
      expect(res.body.ok).toBe(true);
      expect(res.body.fromCode).toBe(userA);
      expect(res.body.fromName).toBe('Alice');

      // Subsequent poll by User B should not list it anymore as pending
      const pollResB = await request(app)
        .get(`/friends/requests/${userB}`)
        .set('Authorization', `Bearer ${tokenB}`);
      const foundB = pollResB.body.requests.find((r) => r.id === createdRequestId);
      expect(foundB).toBeUndefined();

      // BIDIRECTIONAL SYNC: User A (sender) polls and sees B accepted!
      const pollResA = await request(app)
        .get(`/friends/requests/${userA}`)
        .set('Authorization', `Bearer ${tokenA}`);
      expect(pollResA.status).toBe(200);
      expect(pollResA.body.accepted).toBeDefined();
      const acceptedFound = pollResA.body.accepted.find((r) => r.id === createdRequestId);
      expect(acceptedFound).toBeDefined();
      expect(acceptedFound.toCode).toBe(userB);

      // User A acknowledges the accepted notification
      const ackRes = await request(app)
        .post('/friends/ack')
        .set('Authorization', `Bearer ${tokenA}`)
        .send({ requestId: createdRequestId });
      expect(ackRes.status).toBe(200);
      expect(ackRes.body.ok).toBe(true);

      // After ack, it is not returned again
      const pollAfterAck = await request(app)
        .get(`/friends/requests/${userA}`)
        .set('Authorization', `Bearer ${tokenA}`);
      const stillAccepted = pollAfterAck.body.accepted.find((r) => r.id === createdRequestId);
      expect(stillAccepted).toBeUndefined();
    });
  });

  describe('POST /friends/decline', () => {
    let declineRequestId;

    beforeAll(async () => {
      const userC = 'KIOKU-CCCC';
      const resC = await request(app).post('/friends/token').send({
        friendCode: userC,
        secret: 'secret-c-device-credentials-12345',
      });
      const tokenC = resC.body.token;

      const res = await request(app)
        .post('/friends/request')
        .set('Authorization', `Bearer ${tokenC}`)
        .send({ toCode: userB, fromName: 'Charlie' });
      declineRequestId = res.body.id;
    });

    it('declines the friend request successfully', async () => {
      const res = await request(app)
        .post('/friends/decline')
        .set('Authorization', `Bearer ${tokenB}`)
        .send({ requestId: declineRequestId });
      expect(res.status).toBe(200);
      expect(res.body.ok).toBe(true);

      const pollRes = await request(app)
        .get(`/friends/requests/${userB}`)
        .set('Authorization', `Bearer ${tokenB}`);
      const found = pollRes.body.requests.find((r) => r.id === declineRequestId);
      expect(found).toBeUndefined();
    });
  });

  describe('Social Album Invitations & Sync Across Accounts', () => {
    let inviteId;
    const albumId = 'album_kyoto_trip_2026';
    const albumName = 'Kyoto Spring 2026';

    it('creates an album invitation for a friend using authenticated token', async () => {
      const res = await request(app)
        .post('/friends/albums/invite')
        .set('Authorization', `Bearer ${tokenA}`)
        .send({
          albumId,
          albumName,
          toCode: userB,
          fromName: 'Alice',
          claimToken: 'tok_claim_12345',
          inviterPubKey: 'pubkey_alice_base64',
        });

      expect(res.status).toBe(200);
      expect(res.body).toHaveProperty('id');
      expect(res.body.status).toBe('pending');
      inviteId = res.body.id;
    });

    it('prevents third party from polling User B album invites (403)', async () => {
      const res = await request(app)
        .get(`/friends/albums/invites/${userB}`)
        .set('Authorization', `Bearer ${tokenA}`);
      expect(res.status).toBe(403);
    });

    it('recipient polls and finds the album invitation with recipient token', async () => {
      const res = await request(app)
        .get(`/friends/albums/invites/${userB}`)
        .set('Authorization', `Bearer ${tokenB}`);

      expect(res.status).toBe(200);
      expect(res.body.invites).toBeDefined();
      const invite = res.body.invites.find((i) => i.id === inviteId);
      expect(invite).toBeDefined();
      expect(invite.albumId).toBe(albumId);
      expect(invite.albumName).toBe(albumName);
      expect(invite.fromCode).toBe(userA);
      expect(invite.claimToken).toBe('tok_claim_12345');
    });

    it('rejects accept from unauthorized user', async () => {
      const res = await request(app)
        .post('/friends/albums/accept')
        .set('Authorization', `Bearer ${tokenA}`) // User A cannot accept invite sent to User B
        .send({ inviteId });
      expect(res.status).toBe(403);
    });

    it('recipient accepts the album invitation', async () => {
      const res = await request(app)
        .post('/friends/albums/accept')
        .set('Authorization', `Bearer ${tokenB}`)
        .send({ inviteId });

      expect(res.status).toBe(200);
      expect(res.body.ok).toBe(true);
      expect(res.body.albumId).toBe(albumId);
      expect(res.body.claimToken).toBe('tok_claim_12345');

      // Subsequent poll should not list it anymore as pending
      const pollRes = await request(app)
        .get(`/friends/albums/invites/${userB}`)
        .set('Authorization', `Bearer ${tokenB}`);
      const found = pollRes.body.invites.find((i) => i.id === inviteId);
      expect(found).toBeUndefined();
    });
  });
});
