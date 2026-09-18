// src/middleware/auth.ts
import { MiddlewareHandler } from 'hono';
import { AppEnv, FriendAuthPayload, LegacyAuthPayload } from '../types';
import { verifyJwt } from '../crypto';

export const requireFriendAuth: MiddlewareHandler<AppEnv> = async (c, next) => {
  const authHeader = c.req.header('authorization');
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return c.json({ error: 'Missing or malformed Authorization header' }, 401);
  }

  const token = authHeader.split(' ')[1];
  const secret = c.env.JWT_SECRET || 'default-dev-secret-change-in-production-please';

  try {
    const decoded = await verifyJwt<FriendAuthPayload>(token, secret);
    if (!decoded || !decoded.friendCode) {
      return c.json({ error: 'Invalid token payload' }, 401);
    }
    c.set('friendCode', decoded.friendCode);
    await next();
  } catch (err) {
    return c.json({ error: 'Invalid or expired authorization token' }, 401);
  }
};

export const requireLegacyAuth: MiddlewareHandler<AppEnv> = async (c, next) => {
  const authHeader = c.req.header('authorization');
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return c.json({ error: 'Missing token' }, 401);
  }

  const token = authHeader.split(' ')[1];
  const secret = c.env.JWT_SECRET || 'default-dev-secret-change-in-production-please';

  try {
    const decoded = await verifyJwt<LegacyAuthPayload>(token, secret);
    if (!decoded || !decoded.userId || !decoded.groupId) {
      return c.json({ error: 'Invalid token payload' }, 401);
    }
    c.set('legacyUser', decoded);
    await next();
  } catch (err) {
    return c.json({ error: 'Invalid or expired token' }, 401);
  }
};
