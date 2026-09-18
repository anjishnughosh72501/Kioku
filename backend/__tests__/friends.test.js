const request = require('supertest');

process.env.JWT_SECRET = 'test-secret-key-1234567890-abcdefg';

const { initDB } = require('../db');
const { createApp } = require('../server');

let app;

beforeAll(async () => {
  await initDB();
  app = createApp();
});

describe('Friend Request & Social Album API Routes', () => {
  const userA = 'KIOKU-AAAA';
  const userB = 'KIOKU-BBBB';
  let createdRequestId;

  describe('POST /friends/request', () => {
    it('rejects missing parameters', async () => {
      const res = await request(app)
        .post('/friends/request')
        .send({ fromCode: userA });
      expect(res.status).toBe(400);
    });

    it('rejects sending friend request to oneself', async () => {
      const res = await request(app)
        .post('/friends/request')
        .send({ fromCode: userA, toCode: userA });
      expect(res.status).toBe(400);
    });

    it('creates a new friend request successfully', async () => {
      const res = await request(app)
        .post('/friends/request')
        .send({ fromCode: userA, toCode: userB, fromName: 'Alice' });

      expect(res.status).toBe(200);
      expect(res.body).toHaveProperty('id');
      expect(res.body.status).toBe('pending');
      expect(res.body.alreadySent).toBe(false);
      createdRequestId = res.body.id;
    });

    it('returns existing request if duplicate pending request is sent', async () => {
      const res = await request(app)
        .post('/friends/request')
        .send({ fromCode: userA, toCode: userB, fromName: 'Alice' });

      expect(res.status).toBe(200);
      expect(res.body.id).toBe(createdRequestId);
      expect(res.body.alreadySent).toBe(true);
    });
  });

  describe('GET /friends/requests/:myCode', () => {
    it('polls pending requests for recipient', async () => {
      const res = await request(app).get(`/friends/requests/${userB}`);
      expect(res.status).toBe(200);
      expect(res.body).toHaveProperty('requests');
      expect(Array.isArray(res.body.requests)).toBe(true);
      const found = res.body.requests.find((r) => r.id === createdRequestId);
      expect(found).toBeDefined();
      expect(found.fromCode).toBe(userA);
      expect(found.fromName).toBe('Alice');
    });

    it('returns empty list for user with no requests', async () => {
      const res = await request(app).get(`/friends/requests/KIOKU-NONE`);
      expect(res.status).toBe(200);
      expect(res.body.requests).toEqual([]);
      expect(res.body.accepted).toEqual([]);
    });
  });

  describe('POST /friends/accept & Bidirectional Sync', () => {
    it('rejects accept from unauthorized user', async () => {
      const res = await request(app)
        .post('/friends/accept')
        .send({ requestId: createdRequestId, myCode: 'KIOKU-IMPOSTOR' });
      expect(res.status).toBe(403);
    });

    it('accepts the friend request successfully', async () => {
      const res = await request(app)
        .post('/friends/accept')
        .send({ requestId: createdRequestId, myCode: userB });
      expect(res.status).toBe(200);
      expect(res.body.ok).toBe(true);
      expect(res.body.fromCode).toBe(userA);
      expect(res.body.fromName).toBe('Alice');

      // Subsequent poll by User B should not list it anymore as pending
      const pollResB = await request(app).get(`/friends/requests/${userB}`);
      const foundB = pollResB.body.requests.find((r) => r.id === createdRequestId);
      expect(foundB).toBeUndefined();

      // BIDIRECTIONAL SYNC: User A (sender) polls and sees B accepted!
      const pollResA = await request(app).get(`/friends/requests/${userA}`);
      expect(pollResA.status).toBe(200);
      expect(pollResA.body.accepted).toBeDefined();
      const acceptedFound = pollResA.body.accepted.find((r) => r.id === createdRequestId);
      expect(acceptedFound).toBeDefined();
      expect(acceptedFound.toCode).toBe(userB);

      // User A acknowledges the accepted notification
      const ackRes = await request(app)
        .post('/friends/ack')
        .send({ requestId: createdRequestId, myCode: userA });
      expect(ackRes.status).toBe(200);
      expect(ackRes.body.ok).toBe(true);

      // After ack, it is not returned again
      const pollAfterAck = await request(app).get(`/friends/requests/${userA}`);
      const stillAccepted = pollAfterAck.body.accepted.find((r) => r.id === createdRequestId);
      expect(stillAccepted).toBeUndefined();
    });
  });

  describe('POST /friends/decline', () => {
    let declineRequestId;

    beforeAll(async () => {
      const res = await request(app)
        .post('/friends/request')
        .send({ fromCode: 'KIOKU-CCCC', toCode: userB, fromName: 'Charlie' });
      declineRequestId = res.body.id;
    });

    it('declines the friend request successfully', async () => {
      const res = await request(app)
        .post('/friends/decline')
        .send({ requestId: declineRequestId, myCode: userB });
      expect(res.status).toBe(200);
      expect(res.body.ok).toBe(true);

      const pollRes = await request(app).get(`/friends/requests/${userB}`);
      const found = pollRes.body.requests.find((r) => r.id === declineRequestId);
      expect(found).toBeUndefined();
    });
  });

  describe('Social Album Invitations & Sync Across Accounts', () => {
    let inviteId;
    const albumId = 'album_kyoto_trip_2026';
    const albumName = 'Kyoto Spring 2026';

    it('creates an album invitation for a friend', async () => {
      const res = await request(app)
        .post('/friends/albums/invite')
        .send({
          albumId,
          albumName,
          fromCode: userA,
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

    it('recipient polls and finds the album invitation', async () => {
      const res = await request(app).get(`/friends/albums/invites/${userB}`);
      expect(res.status).toBe(200);
      expect(res.body.invites).toBeDefined();
      const invite = res.body.invites.find((i) => i.id === inviteId);
      expect(invite).toBeDefined();
      expect(invite.albumId).toBe(albumId);
      expect(invite.albumName).toBe(albumName);
      expect(invite.fromCode).toBe(userA);
      expect(invite.claimToken).toBe('tok_claim_12345');
    });

    it('recipient accepts the album invitation', async () => {
      const res = await request(app)
        .post('/friends/albums/accept')
        .send({ inviteId, myCode: userB });

      expect(res.status).toBe(200);
      expect(res.body.ok).toBe(true);
      expect(res.body.albumId).toBe(albumId);
      expect(res.body.claimToken).toBe('tok_claim_12345');

      // Subsequent poll should not list it anymore as pending
      const pollRes = await request(app).get(`/friends/albums/invites/${userB}`);
      const found = pollRes.body.invites.find((i) => i.id === inviteId);
      expect(found).toBeUndefined();
    });

    it('rejects accept from unauthorized user', async () => {
      const res = await request(app)
        .post('/friends/albums/accept')
        .send({ inviteId, myCode: 'KIOKU-HACKER' });
      expect(res.status).toBe(403);
    });
  });
});
