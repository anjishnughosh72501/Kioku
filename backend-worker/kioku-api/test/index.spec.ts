import { env, createExecutionContext, waitOnExecutionContext } from 'cloudflare:test';
import { describe, it, expect, beforeAll } from 'vitest';
import worker from '../src/index';

const schemaSql = `
CREATE TABLE IF NOT EXISTS groups (
  id            TEXT PRIMARY KEY,
  name          TEXT NOT NULL,
  invite_code   TEXT UNIQUE NOT NULL,
  drive_folder_id TEXT,
  created_at    TEXT DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS users (
  id          TEXT PRIMARY KEY,
  name        TEXT NOT NULL,
  group_id    TEXT NOT NULL REFERENCES groups(id),
  created_at  TEXT DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS media (
  id              TEXT PRIMARY KEY,
  drive_file_id   TEXT NOT NULL,
  group_id        TEXT NOT NULL REFERENCES groups(id),
  uploader_id     TEXT NOT NULL REFERENCES users(id),
  type            TEXT NOT NULL CHECK(type IN ('photo', 'video')),
  caption         TEXT,
  taken_at        TEXT,
  uploaded_at     TEXT DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS flashbacks (
  id            TEXT PRIMARY KEY,
  group_id      TEXT NOT NULL REFERENCES groups(id),
  period        TEXT NOT NULL CHECK(period IN ('daily', 'weekly', 'monthly', 'yearly')),
  generated_for TEXT NOT NULL,
  media_ids     TEXT NOT NULL,
  created_at    TEXT DEFAULT (datetime('now')),
  UNIQUE(group_id, period, generated_for)
);

CREATE TABLE IF NOT EXISTS claim_tokens (
  token           TEXT PRIMARY KEY,
  album_id        TEXT NOT NULL,
  inviter_pub_key TEXT NOT NULL,
  recipient_pub_key TEXT,
  sealed_key      TEXT,
  expires_at      INTEGER NOT NULL,
  used            INTEGER DEFAULT 0,
  created_at      TEXT DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS friend_requests (
  id              TEXT PRIMARY KEY,
  from_code       TEXT NOT NULL,
  to_code         TEXT NOT NULL,
  from_name       TEXT,
  status          TEXT DEFAULT 'pending',
  created_at      INTEGER NOT NULL,
  updated_at      INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS album_invites (
  id              TEXT PRIMARY KEY,
  album_id        TEXT NOT NULL,
  album_name      TEXT NOT NULL,
  from_code       TEXT NOT NULL,
  to_code         TEXT NOT NULL,
  from_name       TEXT,
  claim_token     TEXT,
  inviter_pub_key TEXT,
  status          TEXT DEFAULT 'pending',
  created_at      INTEGER NOT NULL,
  updated_at      INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS friend_accounts (
  friend_code     TEXT PRIMARY KEY,
  secret_hash     TEXT NOT NULL,
  username        TEXT,
  created_at      INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS friends (
  user_a          TEXT NOT NULL,
  user_b          TEXT NOT NULL,
  created_at      INTEGER NOT NULL,
  PRIMARY KEY (user_a, user_b)
);

CREATE TABLE IF NOT EXISTS invites (
  id              TEXT PRIMARY KEY,
  invite_code     TEXT UNIQUE NOT NULL,
  created_by      TEXT NOT NULL,
  from_name       TEXT,
  expires_at      INTEGER NOT NULL,
  status          TEXT DEFAULT 'valid',
  created_at      INTEGER NOT NULL
);
`;

async function dispatch(
  path: string,
  options: {
    method?: string;
    headers?: Record<string, string>;
    body?: any;
  } = {}
) {
  const url = `http://example.com${path}`;
  const headers: Record<string, string> = {
    ...options.headers,
  };

  let bodyStr: string | undefined = undefined;
  if (options.body !== undefined) {
    headers['Content-Type'] = 'application/json';
    bodyStr = JSON.stringify(options.body);
  }

  const req = new Request(url, {
    method: options.method || 'GET',
    headers,
    body: bodyStr,
  });

  const ctx = createExecutionContext();
  const res = await worker.fetch(req, env, ctx);
  await waitOnExecutionContext(ctx);
  return res;
}

beforeAll(async () => {
  const statements = schemaSql
    .split(';')
    .map((s) => s.trim())
    .filter((s) => s.length > 0);

  for (const stmt of statements) {
    await env.DB.prepare(stmt).run();
  }
});

describe('Kioku Cloudflare Worker API Suite', () => {
  const userA = 'KIOKU-ALICE';
  const secretA = 'secure-device-secret-for-alice-12345';
  let tokenA: string;

  const userB = 'KIOKU-BOB123';
  const secretB = 'secure-device-secret-for-bob-123456';
  let tokenB: string;

  let createdRequestId: string;

  describe('Health & Static Endpoints', () => {
    it('GET /health returns 200 { ok: true }', async () => {
      const res = await dispatch('/health');
      expect(res.status).toBe(200);
      const data = (await res.json()) as any;
      expect(data).toEqual({ ok: true });
    });

    it('GET /privacy returns privacy policy markdown', async () => {
      const res = await dispatch('/privacy');
      expect(res.status).toBe(200);
      const text = await res.text();
      expect(text).toContain('Kioku Privacy Policy');
    });

    it('GET /terms returns terms of service', async () => {
      const res = await dispatch('/terms');
      expect(res.status).toBe(200);
      const text = await res.text();
      expect(text).toContain('Kioku Terms of Service');
    });
  });

  describe('POST /friends/token (Device Authentication)', () => {
    it('rejects registration with missing parameters', async () => {
      const res = await dispatch('/friends/token', {
        method: 'POST',
        body: { friendCode: userA },
      });
      expect(res.status).toBe(400);
    });

    it('rejects short secrets (< 16 chars)', async () => {
      const res = await dispatch('/friends/token', {
        method: 'POST',
        body: { friendCode: userA, secret: 'short' },
      });
      expect(res.status).toBe(400);
    });

    it('issues signed JWT for valid friendCode and secret', async () => {
      const resA = await dispatch('/friends/token', {
        method: 'POST',
        body: { friendCode: userA, secret: secretA, username: 'Alice' },
      });
      expect(resA.status).toBe(200);
      const dataA = (await resA.json()) as any;
      expect(dataA).toHaveProperty('token');
      expect(dataA.friendCode).toBe(userA);
      tokenA = dataA.token;

      const resB = await dispatch('/friends/token', {
        method: 'POST',
        body: { friendCode: userB, secret: secretB, username: 'Bob' },
      });
      expect(resB.status).toBe(200);
      const dataB = (await resB.json()) as any;
      expect(dataB).toHaveProperty('token');
      expect(dataB.friendCode).toBe(userB);
      tokenB = dataB.token;
    });

    it('rejects token request with incorrect secret for existing code', async () => {
      const res = await dispatch('/friends/token', {
        method: 'POST',
        body: { friendCode: userA, secret: 'wrong-secret-12345678' },
      });
      expect(res.status).toBe(401);
    });
  });

  describe('Authorization Enforcement on /friends/*', () => {
    it('rejects requests without Authorization header with 401', async () => {
      const res = await dispatch('/friends/request', {
        method: 'POST',
        body: { toCode: userB },
      });
      expect(res.status).toBe(401);
    });

    it('rejects requests with forged/tampered token with 401', async () => {
      const res = await dispatch('/friends/request', {
        method: 'POST',
        headers: { Authorization: 'Bearer invalid-jwt-token' },
        body: { toCode: userB },
      });
      expect(res.status).toBe(401);
    });

    it('prevents User A from polling User B requests (403 Forbidden)', async () => {
      const res = await dispatch(`/friends/requests/${userB}`, {
        headers: { Authorization: `Bearer ${tokenA}` },
      });
      expect(res.status).toBe(403);
    });
  });

  describe('Friend Request Lifecycle & Bidirectional Sync', () => {
    it('rejects missing toCode parameter', async () => {
      const res = await dispatch('/friends/request', {
        method: 'POST',
        headers: { Authorization: `Bearer ${tokenA}` },
        body: {},
      });
      expect(res.status).toBe(400);
    });

    it('rejects sending friend request to oneself', async () => {
      const res = await dispatch('/friends/request', {
        method: 'POST',
        headers: { Authorization: `Bearer ${tokenA}` },
        body: { toCode: userA },
      });
      expect(res.status).toBe(400);
    });

    it('creates a new friend request successfully', async () => {
      const res = await dispatch('/friends/request', {
        method: 'POST',
        headers: { Authorization: `Bearer ${tokenA}` },
        body: { toCode: userB, fromName: 'Alice' },
      });

      expect(res.status).toBe(200);
      const data = (await res.json()) as any;
      expect(data).toHaveProperty('id');
      expect(data.status).toBe('pending');
      expect(data.alreadySent).toBe(false);
      createdRequestId = data.id;
    });

    it('returns existing request if duplicate pending request is sent', async () => {
      const res = await dispatch('/friends/request', {
        method: 'POST',
        headers: { Authorization: `Bearer ${tokenA}` },
        body: { toCode: userB, fromName: 'Alice' },
      });

      expect(res.status).toBe(200);
      const data = (await res.json()) as any;
      expect(data.id).toBe(createdRequestId);
      expect(data.alreadySent).toBe(true);
    });

    it('polls pending requests for recipient using their own token', async () => {
      const res = await dispatch(`/friends/requests/${userB}`, {
        headers: { Authorization: `Bearer ${tokenB}` },
      });

      expect(res.status).toBe(200);
      const data = (await res.json()) as any;
      expect(data).toHaveProperty('requests');
      const found = data.requests.find((r: any) => r.id === createdRequestId);
      expect(found).toBeDefined();
      expect(found.fromCode).toBe(userA);
      expect(found.fromName).toBe('Alice');
    });

    it('User A sees request in GET /friends/sent/:myCode', async () => {
      const res = await dispatch(`/friends/sent/${userA}`, {
        headers: { Authorization: `Bearer ${tokenA}` },
      });

      expect(res.status).toBe(200);
      const data = (await res.json()) as any;
      const sent = data.requests.find((r: any) => r.id === createdRequestId);
      expect(sent).toBeDefined();
      expect(sent.toCode).toBe(userB);
      expect(sent.toName).toBe('Bob');
      expect(sent.status).toBe('pending');
    });

    it('rejects accept from unauthorized user (403)', async () => {
      const res = await dispatch('/friends/accept', {
        method: 'POST',
        headers: { Authorization: `Bearer ${tokenA}` },
        body: { requestId: createdRequestId },
      });
      expect(res.status).toBe(403);
    });

    it('accepts the friend request successfully with recipient token', async () => {
      const res = await dispatch('/friends/accept', {
        method: 'POST',
        headers: { Authorization: `Bearer ${tokenB}` },
        body: { requestId: createdRequestId },
      });

      expect(res.status).toBe(200);
      const data = (await res.json()) as any;
      expect(data.ok).toBe(true);
      expect(data.fromCode).toBe(userA);
      expect(data.fromName).toBe('Alice');

      // User A (sender) polls and sees accepted request!
      const pollResA = await dispatch(`/friends/requests/${userA}`, {
        headers: { Authorization: `Bearer ${tokenA}` },
      });
      expect(pollResA.status).toBe(200);
      const pollDataA = (await pollResA.json()) as any;
      const acceptedFound = pollDataA.accepted.find((r: any) => r.id === createdRequestId);
      expect(acceptedFound).toBeDefined();
      expect(acceptedFound.toCode).toBe(userB);

      // User A acknowledges the accepted notification
      const ackRes = await dispatch('/friends/ack', {
        method: 'POST',
        headers: { Authorization: `Bearer ${tokenA}` },
        body: { requestId: createdRequestId },
      });
      expect(ackRes.status).toBe(200);

      // Both users appear in normalized friends list
      const listA = await dispatch(`/friends/list/${userA}`, {
        headers: { Authorization: `Bearer ${tokenA}` },
      });
      const listDataA = (await listA.json()) as any;
      expect(listDataA.friends.some((f: any) => f.friendCode === userB)).toBe(true);

      const listB = await dispatch(`/friends/list/${userB}`, {
        headers: { Authorization: `Bearer ${tokenB}` },
      });
      const listDataB = (await listB.json()) as any;
      expect(listDataB.friends.some((f: any) => f.friendCode === userA)).toBe(true);
    });

    it('removes a friend relationship', async () => {
      const removeRes = await dispatch('/friends/remove', {
        method: 'POST',
        headers: { Authorization: `Bearer ${tokenA}` },
        body: { friendCode: userB },
      });
      expect(removeRes.status).toBe(200);

      const checkA = await dispatch(`/friends/list/${userA}`, {
        headers: { Authorization: `Bearer ${tokenA}` },
      });
      const checkDataA = (await checkA.json()) as any;
      expect(checkDataA.friends.some((f: any) => f.friendCode === userB)).toBe(false);
    });
  });

  describe('Universal Short Invites & Landing Page', () => {
    let inviteCode: string;

    it('creates short universal invite code with kioku.app URL', async () => {
      const res = await dispatch('/friends/invite', {
        method: 'POST',
        headers: { Authorization: `Bearer ${tokenA}` },
        body: { fromName: 'Alice' },
      });

      expect(res.status).toBe(200);
      const data = (await res.json()) as any;
      expect(data.code).toBeDefined();
      expect(data.code.length).toBe(6);
      expect(data.url).toBe(`https://kioku.app/i/${data.code}`);
      inviteCode = data.code;
    });

    it('resolves invite code publicly via GET /invite/:code', async () => {
      const res = await dispatch(`/invite/${inviteCode}`);
      expect(res.status).toBe(200);
      const data = (await res.json()) as any;
      expect(data.status).toBe('valid');
      expect(data.friendCode).toBe(userA);
      expect(data.username).toBe('Alice');
    });

    it('returns 404 for non-existent invite code', async () => {
      const res = await dispatch('/invite/NONEXIST');
      expect(res.status).toBe(404);
      const data = (await res.json()) as any;
      expect(data.status).toBe('invalid');
    });

    it('returns HTML landing page when Accept header specifies text/html', async () => {
      const res = await dispatch(`/i/${inviteCode}`, {
        headers: { Accept: 'text/html' },
      });

      expect(res.status).toBe(200);
      const contentType = res.headers.get('content-type') || '';
      expect(contentType).toContain('text/html');
      const text = await res.text();
      expect(text).toContain('Connect with Alice');
      expect(text).toContain(`kioku://i/${inviteCode}`);
    });
  });

  describe('Social Album Invitations', () => {
    let albumInviteId: string;
    const albumId = 'album_kyoto_trip_2026';
    const albumName = 'Kyoto Spring 2026';

    it('creates an album invitation for a friend using authenticated token', async () => {
      const res = await dispatch('/friends/albums/invite', {
        method: 'POST',
        headers: { Authorization: `Bearer ${tokenA}` },
        body: {
          albumId,
          albumName,
          toCode: userB,
          fromName: 'Alice',
          claimToken: 'tok_claim_12345',
          inviterPubKey: 'pubkey_alice_base64',
        },
      });

      expect(res.status).toBe(200);
      const data = (await res.json()) as any;
      expect(data).toHaveProperty('id');
      expect(data.status).toBe('pending');
      albumInviteId = data.id;
    });

    it('recipient polls and finds the album invitation with recipient token', async () => {
      const res = await dispatch(`/friends/albums/invites/${userB}`, {
        headers: { Authorization: `Bearer ${tokenB}` },
      });

      expect(res.status).toBe(200);
      const data = (await res.json()) as any;
      const invite = data.invites.find((i: any) => i.id === albumInviteId);
      expect(invite).toBeDefined();
      expect(invite.albumId).toBe(albumId);
      expect(invite.albumName).toBe(albumName);
      expect(invite.fromCode).toBe(userA);
      expect(invite.claimToken).toBe('tok_claim_12345');
    });

    it('recipient accepts the album invitation', async () => {
      const res = await dispatch('/friends/albums/accept', {
        method: 'POST',
        headers: { Authorization: `Bearer ${tokenB}` },
        body: { inviteId: albumInviteId },
      });

      expect(res.status).toBe(200);
      const data = (await res.json()) as any;
      expect(data.ok).toBe(true);
      expect(data.albumId).toBe(albumId);
      expect(data.claimToken).toBe('tok_claim_12345');
    });
  });

  describe('Claim Token Key Exchange', () => {
    let claimToken: string;

    it('creates single-use claim token', async () => {
      const res = await dispatch('/claim/request', {
        method: 'POST',
        body: {
          albumId: 'album_test_123',
          inviterPubKey: 'inviter_pub_key_base64',
        },
      });

      expect(res.status).toBe(200);
      const data = (await res.json()) as any;
      expect(data.claimToken).toBeDefined();
      expect(data.expiresAt).toBeGreaterThan(Date.now());
      claimToken = data.claimToken;
    });

    it('redeems claim token with recipient public key', async () => {
      const res = await dispatch('/claim/redeem', {
        method: 'POST',
        body: {
          claimToken,
          recipientPubKey: 'recipient_pub_key_base64',
        },
      });

      expect(res.status).toBe(200);
      const data = (await res.json()) as any;
      expect(data.albumId).toBe('album_test_123');
      expect(data.inviterPubKey).toBe('inviter_pub_key_base64');
    });

    it('rejects duplicate redemption (410 Already Used)', async () => {
      const res = await dispatch('/claim/redeem', {
        method: 'POST',
        body: {
          claimToken,
          recipientPubKey: 'another_key',
        },
      });
      expect(res.status).toBe(410);
    });

    it('posts sealed collection key', async () => {
      const res = await dispatch('/claim/seal', {
        method: 'POST',
        body: {
          claimToken,
          sealedKey: 'encrypted_sealed_album_key_ciphertext',
        },
      });

      expect(res.status).toBe(200);
      const data = (await res.json()) as any;
      expect(data.ok).toBe(true);
    });

    it('joining device retrieves sealed collection key', async () => {
      const res = await dispatch(`/claim/sealed/${claimToken}`);
      expect(res.status).toBe(200);
      const data = (await res.json()) as any;
      expect(data.albumId).toBe('album_test_123');
      expect(data.sealedKey).toBe('encrypted_sealed_album_key_ciphertext');
      expect(data.recipientPubKey).toBe('recipient_pub_key_base64');
    });
  });

  describe('Update Profile Username', () => {
    it('updates username for authenticated user', async () => {
      const res = await dispatch('/friends/profile', {
        method: 'POST',
        headers: { Authorization: `Bearer ${tokenA}` },
        body: { username: 'Alice In Wonderland' },
      });

      expect(res.status).toBe(200);
      const data = (await res.json()) as any;
      expect(data.ok).toBe(true);
      expect(data.username).toBe('Alice In Wonderland');
    });
  });

  describe('Cancel, Resend, and Decline Requests', () => {
    let cancelReqId: string;
    const userC = 'KIOKU-CHARLIE';

    it('creates and cancels a pending friend request', async () => {
      const createRes = await dispatch('/friends/request', {
        method: 'POST',
        headers: { Authorization: `Bearer ${tokenA}` },
        body: { toCode: userC, fromName: 'Alice' },
      });
      expect(createRes.status).toBe(200);
      const data = (await createRes.json()) as any;
      cancelReqId = data.id;

      const cancelRes = await dispatch('/friends/cancel', {
        method: 'POST',
        headers: { Authorization: `Bearer ${tokenA}` },
        body: { requestId: cancelReqId },
      });
      expect(cancelRes.status).toBe(200);
      const cancelData = (await cancelRes.json()) as any;
      expect(cancelData.ok).toBe(true);
    });

    it('resends a cancelled request', async () => {
      const resendRes = await dispatch('/friends/resend', {
        method: 'POST',
        headers: { Authorization: `Bearer ${tokenA}` },
        body: { requestId: cancelReqId },
      });
      expect(resendRes.status).toBe(200);
      const resendData = (await resendRes.json()) as any;
      expect(resendData.ok).toBe(true);

      const sentRes = await dispatch(`/friends/sent/${userA}`, {
        headers: { Authorization: `Bearer ${tokenA}` },
      });
      const sentData = (await sentRes.json()) as any;
      const found = sentData.requests.find((r: any) => r.id === cancelReqId);
      expect(found.status).toBe('pending');
    });

    it('declines a friend request', async () => {
      const declineRes = await dispatch('/friends/decline', {
        method: 'POST',
        headers: { Authorization: `Bearer ${tokenB}` },
        body: { requestId: createdRequestId },
      });
      expect(declineRes.status).toBe(200);
    });
  });

  describe('Signaling Protocol Upgrade Verification', () => {
    it('returns 426 when Upgrade header is missing', async () => {
      const res = await dispatch('/signal');
      expect(res.status).toBe(426);
    });

    it('returns 401 when token query param is missing on WebSocket request', async () => {
      const res = await dispatch('/signal', {
        headers: { Upgrade: 'websocket' },
      });
      expect(res.status).toBe(401);
    });

    it('returns 401 when token is invalid', async () => {
      const res = await dispatch('/signal?token=invalid', {
        headers: { Upgrade: 'websocket' },
      });
      expect(res.status).toBe(401);
    });
  });

  describe('Legacy Group & Member Auth Endpoints', () => {
    let groupId: string;
    let legacyToken: string;

    it('creates a new group via POST /auth/groups', async () => {
      const res = await dispatch('/auth/groups', {
        method: 'POST',
        body: { groupName: 'Close Friends' },
      });
      expect(res.status).toBe(200);
      const data = (await res.json()) as any;
      expect(data.groupId).toBeDefined();
      expect(data.inviteCode).toBeDefined();
      groupId = data.groupId;

      // Friend joins
      const joinRes = await dispatch('/auth/join', {
        method: 'POST',
        body: { inviteCode: data.inviteCode, name: 'Dana' },
      });
      expect(joinRes.status).toBe(200);
      const joinData = (await joinRes.json()) as any;
      expect(joinData.token).toBeDefined();
      expect(joinData.groupName).toBe('Close Friends');
      legacyToken = joinData.token;
    });

    it('authenticates GET /auth/me with legacy token', async () => {
      const res = await dispatch('/auth/me', {
        headers: { Authorization: `Bearer ${legacyToken}` },
      });
      expect(res.status).toBe(200);
      const data = (await res.json()) as any;
      expect(data.name).toBe('Dana');
      expect(data.groupName).toBe('Close Friends');
      expect(data.role).toBe('member');
    });
  });

  describe('Scheduled Flashback Worker Handler', () => {
    it('executes scheduled cron handler without throwing', async () => {
      const ctx = createExecutionContext();
      const controller = {
        cron: '0 6 * * *',
        scheduledTime: Date.now(),
        noRetry: () => {},
      } as any;

      await worker.scheduled(controller, env, ctx);
      await waitOnExecutionContext(ctx);
      expect(true).toBe(true);
    });
  });
});
