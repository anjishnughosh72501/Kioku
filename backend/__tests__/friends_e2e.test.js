process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test-jwt-secret-key-that-is-at-least-32-chars-long!';

const request = require('supertest');
const { createApp } = require('../server');
const db = require('../db');

describe('Kioku Friends & Invites End-to-End System Tests', () => {
  let app;
  let tokenA, tokenB, userAId, userBId;
  const userACode = 'KIOKU-ALICE' + Math.random().toString(36).substring(2, 5).toUpperCase();
  const userBCode = 'KIOKU-BOB' + Math.random().toString(36).substring(2, 5).toUpperCase();
  const secretA = 'secure-device-secret-alice-123456';
  const secretB = 'secure-device-secret-bob-123456';

  beforeAll(async () => {
    await db.initDB();
    app = createApp();

    // Register User A
    const resA = await request(app).post('/friends/token').send({
      friendCode: userACode,
      secret: secretA,
      username: 'Alice Explorer',
    });
    expect(resA.status).toBe(200);
    expect(resA.body).toHaveProperty('token');
    expect(resA.body.user).toBeDefined();
    expect(resA.body.user.id).toBeDefined();
    expect(resA.body.user.friendCode).toBe(userACode);
    expect(resA.body.user.username).toBe('Alice Explorer');
    tokenA = resA.body.token;
    userAId = resA.body.user.id;

    // Register User B
    const resB = await request(app).post('/friends/token').send({
      friendCode: userBCode,
      secret: secretB,
      username: 'Bob Builder',
    });
    expect(resB.status).toBe(200);
    expect(resB.body.user).toBeDefined();
    tokenB = resB.body.token;
    userBId = resB.body.user.id;
  });

  describe('Android App Links & iOS Universal Links Verification', () => {
    it('serves /.well-known/assetlinks.json with com.kioku.app and SHA-256 fingerprint', async () => {
      const res = await request(app).get('/.well-known/assetlinks.json');
      expect(res.status).toBe(200);
      expect(res.headers['content-type']).toContain('application/json');
      expect(Array.isArray(res.body)).toBe(true);
      expect(res.body[0].target.package_name).toBe('com.kioku.app');
      expect(res.body[0].target.sha256_cert_fingerprints).toBeDefined();
      expect(res.body[0].target.sha256_cert_fingerprints[0]).toContain(':');
    });

    it('serves /.well-known/apple-app-site-association for iOS Universal Links', async () => {
      const res = await request(app).get('/.well-known/apple-app-site-association');
      expect(res.status).toBe(200);
      expect(res.headers['content-type']).toContain('application/json');
      expect(res.body).toHaveProperty('applinks');
    });
  });

  describe('Method A: Friend Code Lookup & Confirmation', () => {
    it('looks up existing user by friend code for pre-send confirmation', async () => {
      const res = await request(app).get(`/friends/lookup/${userBCode}`);
      expect(res.status).toBe(200);
      expect(res.body.exists).toBe(true);
      expect(res.body.friendCode).toBe(userBCode);
      expect(res.body.username).toBe('Bob Builder');
    });

    it('returns 404 for non-existent friend code lookup', async () => {
      const res = await request(app).get('/friends/lookup/KIOKU-DOESNOTEXIST');
      expect(res.status).toBe(404);
      expect(res.body.exists).toBe(false);
    });
  });

  describe('Method B: Universal Short Invites & Resolution', () => {
    let inviteCode;

    it('generates short universal invite link without secrets in URL', async () => {
      const res = await request(app)
        .post('/friends/invite')
        .set('Authorization', `Bearer ${tokenA}`)
        .send({ fromName: 'Alice Explorer' });

      expect(res.status).toBe(200);
      expect(res.body.code).toBeDefined();
      expect(res.body.url).toBe(`https://kioku.app/i/${res.body.code}`);
      expect(res.body.url).not.toContain('secret');
      expect(res.body.url).not.toContain('token');
      inviteCode = res.body.code;
    });

    it('resolves valid invite code publicly', async () => {
      const res = await request(app).get(`/friends/invite/${inviteCode}`);
      expect(res.status).toBe(200);
      expect(res.body.status).toBe('valid');
      expect(res.body.friendCode).toBe(userACode);
      expect(res.body.username).toBe('Alice Explorer');
    });

    it('serves landing page HTML with Join on Kioku and Copy Code button', async () => {
      const res = await request(app)
        .get(`/i/${inviteCode}`)
        .set('Accept', 'text/html');

      expect(res.status).toBe(200);
      expect(res.text).toContain('Join on Kioku');
      expect(res.text).toContain('Download Kioku App (Android)');
      expect(res.text).toContain('copyInvite()');
    });

    it('Device B confirms/claims Device A invite: creates outgoing request for A and incoming for B', async () => {
      // User C enters the scene
      const userCCode = 'KIOKU-C' + Math.random().toString(36).substring(2, 5).toUpperCase();
      const resC = await request(app).post('/friends/token').send({
        friendCode: userCCode,
        secret: 'device-secret-charlie-9876543210',
        username: 'Charlie Baker',
      });
      const tokenC = resC.body.token;

      // User C confirms Alice's inviteCode
      const confirmRes = await request(app)
        .post('/friends/invite/confirm')
        .set('Authorization', `Bearer ${tokenC}`)
        .send({ inviteCode });

      expect(confirmRes.status).toBe(200);
      expect(confirmRes.body.status).toBe('pending');
      expect(confirmRes.body.fromCode).toBe(userACode);
      expect(confirmRes.body.toCode).toBe(userCCode);
      const claimReqId = confirmRes.body.id;

      // Device A (Alice) sees OUTGOING request under /friends/sent/:userACode
      const sentA = await request(app)
        .get(`/friends/sent/${userACode}`)
        .set('Authorization', `Bearer ${tokenA}`);
      expect(sentA.status).toBe(200);
      const outgoing = sentA.body.requests.find((r) => r.id === claimReqId);
      expect(outgoing).toBeDefined();
      expect(outgoing.toCode).toBe(userCCode);
      expect(outgoing.status).toBe('pending');

      // Device B (Charlie) sees INCOMING request under /friends/requests/:userCCode
      const reqC = await request(app)
        .get(`/friends/requests/${userCCode}`)
        .set('Authorization', `Bearer ${tokenC}`);
      expect(reqC.status).toBe(200);
      const incoming = reqC.body.requests.find((r) => r.id === claimReqId);
      expect(incoming).toBeDefined();
      expect(incoming.fromCode).toBe(userACode);

      // Device B (Charlie) accepts request
      const acceptRes = await request(app)
        .post('/friends/accept')
        .set('Authorization', `Bearer ${tokenC}`)
        .send({ requestId: claimReqId });
      expect(acceptRes.status).toBe(200);

      // Both devices show each other under friends list
      const listA = await request(app)
        .get(`/friends/list/${userACode}`)
        .set('Authorization', `Bearer ${tokenA}`);
      expect(listA.body.friends.some((f) => f.friendCode === userCCode)).toBe(true);

      const listC = await request(app)
        .get(`/friends/list/${userCCode}`)
        .set('Authorization', `Bearer ${tokenC}`);
      expect(listC.body.friends.some((f) => f.friendCode === userACode)).toBe(true);
    });
  });


  describe('Friend Request State Machine & Bidirectional Atomic Sync', () => {
    let requestId;

    it('rejects sending friend request to oneself', async () => {
      const res = await request(app)
        .post('/friends/request')
        .set('Authorization', `Bearer ${tokenA}`)
        .send({ toCode: userACode });

      expect(res.status).toBe(400);
    });

    it('User A sends friend request to User B', async () => {
      const res = await request(app)
        .post('/friends/request')
        .set('Authorization', `Bearer ${tokenA}`)
        .send({ toCode: userBCode, fromName: 'Alice Explorer' });

      expect(res.status).toBe(200);
      expect(res.body.status).toBe('pending');
      expect(res.body.alreadySent).toBe(false);
      requestId = res.body.id;
    });

    it('User A sending duplicate request returns existing request with alreadySent: true', async () => {
      const res = await request(app)
        .post('/friends/request')
        .set('Authorization', `Bearer ${tokenA}`)
        .send({ toCode: userBCode });

      expect(res.status).toBe(200);
      expect(res.body.id).toBe(requestId);
      expect(res.body.alreadySent).toBe(true);
    });

    it('User B sees incoming request in GET /friends/requests', async () => {
      const res = await request(app)
        .get(`/friends/requests/${userBCode}`)
        .set('Authorization', `Bearer ${tokenB}`);

      expect(res.status).toBe(200);
      const req = res.body.requests.find((r) => r.id === requestId);
      expect(req).toBeDefined();
      expect(req.fromCode).toBe(userACode);
    });

    it('prevents third party from accepting request (IDOR prevention)', async () => {
      const userHacker = 'KIOKU-HACK' + Math.random().toString(36).substring(2, 5).toUpperCase();
      const resHacker = await request(app).post('/friends/token').send({
        friendCode: userHacker,
        secret: 'hacker-device-secret-1234567890',
      });
      const tokenHacker = resHacker.body.token;

      const res = await request(app)
        .post('/friends/accept')
        .set('Authorization', `Bearer ${tokenHacker}`)
        .send({ requestId });

      expect(res.status).toBe(403);
    });

    it('User B accepts request in atomic transaction and creates friendship', async () => {
      const res = await request(app)
        .post('/friends/accept')
        .set('Authorization', `Bearer ${tokenB}`)
        .send({ requestId });

      expect(res.status).toBe(200);
      expect(res.body.ok).toBe(true);

      // Both appear in normalized friends list with pagination
      const listA = await request(app)
        .get(`/friends/list/${userACode}?limit=10&offset=0`)
        .set('Authorization', `Bearer ${tokenA}`);
      expect(listA.status).toBe(200);
      expect(listA.body.friends.some((f) => f.friendCode === userBCode)).toBe(true);
      expect(listA.body.total).toBeGreaterThanOrEqual(1);

      const listB = await request(app)
        .get(`/friends/list/${userBCode}?limit=10&offset=0`)
        .set('Authorization', `Bearer ${tokenB}`);
      expect(listB.status).toBe(200);
      expect(listB.body.friends.some((f) => f.friendCode === userACode)).toBe(true);
    });

    it('prevents sending friend request after friendship is already established', async () => {
      const res = await request(app)
        .post('/friends/request')
        .set('Authorization', `Bearer ${tokenA}`)
        .send({ toCode: userBCode });

      expect(res.status).toBe(200);
      expect(res.body.alreadyFriends).toBe(true);
    });
  });
});
