const request = require('supertest');

// Mock driveService so tests don't require real Google credentials
jest.mock('../services/driveService', () => ({
  ensureGroupFolder: jest.fn().mockResolvedValue('mock-drive-folder-id'),
  uploadFile: jest.fn().mockResolvedValue({
    fileId: 'mock-file-id-123',
    viewUrl: 'https://drive.google.com/uc?export=view&id=mock-file-id-123',
    thumbnailUrl: 'https://drive.google.com/thumbnail?id=mock-file-id-123&sz=w500',
  }),
}));

process.env.JWT_SECRET = 'test-secret-key-1234567890-abcdefg';

const { initDB } = require('../db');
const { createApp } = require('../server');

let app;
let token;
let groupId;

beforeAll(async () => {
  await initDB();
  app = createApp();

  // Create a group and member to authenticate with
  const groupRes = await request(app)
    .post('/auth/groups')
    .send({ groupName: 'Media Test Circle' });
  groupId = groupRes.body.groupId;
  const inviteCode = groupRes.body.inviteCode;

  const joinRes = await request(app)
    .post('/auth/join')
    .send({ inviteCode, name: 'Tester' });
  token = joinRes.body.token;
});

describe('Media & Auth Refresh Routes', () => {
  describe('POST /auth/refresh', () => {
    it('returns 401 when unauthenticated', async () => {
      const res = await request(app).post('/auth/refresh');
      expect(res.status).toBe(401);
    });

    it('refreshes token successfully for valid bearer', async () => {
      const res = await request(app)
        .post('/auth/refresh')
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(200);
      expect(res.body).toHaveProperty('token');
      expect(res.body.name).toBe('Tester');
      expect(res.body.groupId).toBe(groupId);
    });
  });

  describe('GET /media/feed', () => {
    it('returns 401 when unauthenticated', async () => {
      const res = await request(app).get('/media/feed');
      expect(res.status).toBe(401);
    });

    it('returns empty array of items for newly created group', async () => {
      const res = await request(app)
        .get('/media/feed')
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(200);
      expect(res.body).toHaveProperty('items');
      expect(Array.isArray(res.body.items)).toBe(true);
      expect(res.body.items.length).toBe(0);
    });
  });

  describe('GET /media/uploaders', () => {
    it('returns 401 when unauthenticated', async () => {
      const res = await request(app).get('/media/uploaders');
      expect(res.status).toBe(401);
    });

    it('returns uploaders list for the group', async () => {
      const res = await request(app)
        .get('/media/uploaders')
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(200);
      expect(res.body).toHaveProperty('uploaders');
      expect(Array.isArray(res.body.uploaders)).toBe(true);
    });
  });

  describe('POST /media/upload validation', () => {
    it('returns 400 when no file is sent', async () => {
      const res = await request(app)
        .post('/media/upload')
        .set('Authorization', `Bearer ${token}`)
        .field('caption', 'A lovely sunset');

      expect(res.status).toBe(400);
      expect(res.body.error).toContain('file is required');
    });

    it('returns 400 when invalid type is provided', async () => {
      const res = await request(app)
        .post('/media/upload')
        .set('Authorization', `Bearer ${token}`)
        .field('type', 'audio')
        .attach('file', Buffer.from('fake data'), 'file.txt');

      expect(res.status).toBe(400);
    });
  });
});
