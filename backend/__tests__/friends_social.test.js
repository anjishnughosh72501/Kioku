process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test-jwt-secret-key-that-is-at-least-32-chars-long!';

const request = require('supertest');
const { createApp } = require('../server');
const db = require('../db');

describe('Social System & Universal Invite System Tests', () => {
  jest.setTimeout(30000);
  let app;
  let tokenA, tokenB;
  const userA = 'USRA' + Math.random().toString(36).substring(2, 6).toUpperCase();
  const userB = 'USRB' + Math.random().toString(36).substring(2, 6).toUpperCase();
  const secretA = 'secret-for-user-a-1234567890';
  const secretB = 'secret-for-user-b-1234567890';

  beforeAll(async () => {
    await db.initDB();
    app = createApp();

    // Setup User A
    const resA = await request(app)
      .post('/friends/token')
      .send({ friendCode: userA, secret: secretA, username: 'Alice' });
    expect(resA.status).toBe(200);
    tokenA = resA.body.token;

    // Setup User B
    const resB = await request(app)
      .post('/friends/token')
      .send({ friendCode: userB, secret: secretB, username: 'Bob' });
    expect(resB.status).toBe(200);
    tokenB = resB.body.token;
  });

  describe('Feature 1: Universal Short Invite Links', () => {
    let inviteCode;

    it('creates short universal invite code with kioku.app URL', async () => {
      const res = await request(app)
        .post('/friends/invite')
        .set('Authorization', `Bearer ${tokenA}`)
        .send({ fromName: 'Alice' });

      expect(res.status).toBe(200);
      expect(res.body.code).toBeDefined();
      expect(res.body.code.length).toBeGreaterThanOrEqual(6);
      expect(res.body.url).toBe(`https://kioku.app/i/${res.body.code}`);
      inviteCode = res.body.code;
    });

    it('resolves invite code publicly via GET /invite/:code', async () => {
      const res = await request(app).get(`/invite/${inviteCode}`);
      expect(res.status).toBe(200);
      expect(res.body.status).toBe('valid');
      expect(res.body.friendCode).toBe(userA);
      expect(res.body.username).toBe('Alice');
    });

    it('returns 404 for non-existent invite code', async () => {
      const res = await request(app).get('/invite/NONEXIST');
      expect(res.status).toBe(404);
      expect(res.body.status).toBe('invalid');
    });

    it('returns HTML landing page when Accept header specifies text/html', async () => {
      const res = await request(app)
        .get(`/i/${inviteCode}`)
        .set('Accept', 'text/html');

      expect(res.status).toBe(200);
      expect(res.headers['content-type']).toContain('text/html');
      expect(res.text).toContain(`Connect with Alice`);
      expect(res.text).toContain(`kioku://i/${inviteCode}`);
      expect(res.text).toContain('Open in Kioku');
    });
  });

  describe('Feature 3 & 4: Friend Request State Machine & Normalized Friends', () => {
    let requestId;

    it('sends friend request from User A to User B', async () => {
      const res = await request(app)
        .post('/friends/request')
        .set('Authorization', `Bearer ${tokenA}`)
        .send({ toCode: userB, fromName: 'Alice' });

      expect(res.status).toBe(200);
      expect(res.body.status).toBe('pending');
      requestId = res.body.id;
    });

    it('User B sees incoming request', async () => {
      const res = await request(app)
        .get(`/friends/requests/${userB}`)
        .set('Authorization', `Bearer ${tokenB}`);

      expect(res.status).toBe(200);
      const incoming = res.body.requests.find((r) => r.id === requestId);
      expect(incoming).toBeDefined();
      expect(incoming.fromCode).toBe(userA);
    });

    it('User A sees sent request in GET /friends/sent/:myCode', async () => {
      const res = await request(app)
        .get(`/friends/sent/${userA}`)
        .set('Authorization', `Bearer ${tokenA}`);

      expect(res.status).toBe(200);
      const sent = res.body.requests.find((r) => r.id === requestId);
      expect(sent).toBeDefined();
      expect(sent.toCode).toBe(userB);
      expect(sent.status).toBe('pending');
    });

    it('User B accepts friend request', async () => {
      const res = await request(app)
        .post('/friends/accept')
        .set('Authorization', `Bearer ${tokenB}`)
        .send({ requestId });

      expect(res.status).toBe(200);
      expect(res.body.ok).toBe(true);
    });

    it('both User A and User B appear in normalized friends list', async () => {
      const resA = await request(app)
        .get(`/friends/list/${userA}`)
        .set('Authorization', `Bearer ${tokenA}`);
      expect(resA.status).toBe(200);
      expect(resA.body.friends.some((f) => f.friendCode === userB)).toBe(true);

      const resB = await request(app)
        .get(`/friends/list/${userB}`)
        .set('Authorization', `Bearer ${tokenB}`);
      expect(resB.status).toBe(200);
      expect(resB.body.friends.some((f) => f.friendCode === userA)).toBe(true);
    });

    it('User A can remove User B from friends', async () => {
      const res = await request(app)
        .post('/friends/remove')
        .set('Authorization', `Bearer ${tokenA}`)
        .send({ friendCode: userB });

      expect(res.status).toBe(200);
      expect(res.body.ok).toBe(true);

      const checkA = await request(app)
        .get(`/friends/list/${userA}`)
        .set('Authorization', `Bearer ${tokenA}`);
      expect(checkA.body.friends.some((f) => f.friendCode === userB)).toBe(false);
    });
  });

  describe('Feature 4: Cancel and Resend Request Flows', () => {
    let reqId2;
    const userC = 'USRC' + Math.random().toString(36).substring(2, 6).toUpperCase();

    it('creates and cancels a pending friend request', async () => {
      const resReq = await request(app)
        .post('/friends/request')
        .set('Authorization', `Bearer ${tokenA}`)
        .send({ toCode: userC, fromName: 'Alice' });

      reqId2 = resReq.body.id;

      const resCancel = await request(app)
        .post('/friends/cancel')
        .set('Authorization', `Bearer ${tokenA}`)
        .send({ requestId: reqId2 });

      expect(resCancel.status).toBe(200);
      expect(resCancel.body.ok).toBe(true);
    });

    it('resends a cancelled request', async () => {
      const resResend = await request(app)
        .post('/friends/resend')
        .set('Authorization', `Bearer ${tokenA}`)
        .send({ requestId: reqId2 });

      expect(resResend.status).toBe(200);
      expect(resResend.body.ok).toBe(true);

      const sent = await request(app)
        .get(`/friends/sent/${userA}`)
        .set('Authorization', `Bearer ${tokenA}`);

      const found = sent.body.requests.find((r) => r.id === reqId2);
      expect(found.status).toBe('pending');
    });
  });
});
