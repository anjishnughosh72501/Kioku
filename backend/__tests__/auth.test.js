const request = require('supertest');

// Mock driveService so tests don't require real Google credentials
jest.mock('../services/driveService', () => ({
  ensureGroupFolder: jest.fn().mockResolvedValue('mock-drive-folder-id'),
  uploadFile: jest.fn(),
}));

process.env.JWT_SECRET = 'test-secret-key-1234567890-abcdefg';

const { initDB } = require('../db');
const { createApp } = require('../server');

let app;

beforeAll(async () => {
  await initDB();
  app = createApp();
});

describe('Auth API Routes', () => {
  let createdInviteCode;

  describe('POST /auth/groups', () => {
    it('creates a group and returns inviteCode', async () => {
      const res = await request(app)
        .post('/auth/groups')
        .send({ groupName: 'Tokyo Trip 2026' });

      expect(res.status).toBe(200);
      expect(res.body).toHaveProperty('groupId');
      expect(res.body).toHaveProperty('inviteCode');
      expect(typeof res.body.inviteCode).toBe('string');
      expect(res.body.inviteCode.length).toBe(8);

      createdInviteCode = res.body.inviteCode;
    });

    it('returns 400 when groupName is empty or missing', async () => {
      const res = await request(app)
        .post('/auth/groups')
        .send({ groupName: '   ' });

      expect(res.status).toBe(400);
      expect(res.body).toHaveProperty('error');
    });
  });

  describe('POST /auth/join', () => {
    it('returns 404 for an invalid invite code', async () => {
      const res = await request(app)
        .post('/auth/join')
        .send({ inviteCode: 'NONEXIST', name: 'Bob' });

      expect(res.status).toBe(404);
      expect(res.body).toHaveProperty('error');
    });

    it('joins successfully with a valid invite code and returns JWT', async () => {
      const res = await request(app)
        .post('/auth/join')
        .send({ inviteCode: createdInviteCode, name: 'Alice' });

      expect(res.status).toBe(200);
      expect(res.body).toHaveProperty('token');
      expect(res.body.groupName).toBe('Tokyo Trip 2026');
    });
  });

  describe('GET /auth/me', () => {
    it('returns 401 when Authorization header is missing', async () => {
      const res = await request(app).get('/auth/me');
      expect(res.status).toBe(401);
    });

    it('returns profile when valid token is provided', async () => {
      const joinRes = await request(app)
        .post('/auth/join')
        .send({ inviteCode: createdInviteCode, name: 'Charlie' });

      const token = joinRes.body.token;

      const res = await request(app)
        .get('/auth/me')
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(200);
      expect(res.body.name).toBe('Charlie');
      expect(res.body.groupName).toBe('Tokyo Trip 2026');
      expect(res.body.inviteCode).toBe(createdInviteCode);
    });
  });
});
