// src/crypto.ts
// Standard Web Crypto API utilities for cryptographic parity with Node.js crypto & jsonwebtoken

const INVITE_CHARS = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
const NANOID_CHARS = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz-';

export function getJwtSecret(env: { JWT_SECRET?: string; ENVIRONMENT?: string }): string {
  const secret = env.JWT_SECRET;
  const isTest =
    typeof (globalThis as any).__vitest_worker__ !== 'undefined' ||
    (typeof process !== 'undefined' && Boolean(process.env?.VITEST)) ||
    Boolean((globalThis as any).VITEST);
  if (!secret || secret === 'default-dev-secret-change-in-production-please') {
    if (env.ENVIRONMENT === 'production' && !isTest) {
      throw new Error('FATAL: JWT_SECRET must be configured via wrangler secret in production.');
    }
    return 'dev-testing-jwt-secret-at-least-32-chars-long!';
  }
  return secret;
}

export async function hashSecret(secret: string): Promise<string> {
  const clean = String(secret).trim();
  const msgUint8 = new TextEncoder().encode(clean);
  const hashBuffer = await crypto.subtle.digest('SHA-256', msgUint8);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  return hashArray.map((b) => b.toString(16).padStart(2, '0')).join('');
}

export function generateInviteCode(): string {
  const bytes = new Uint8Array(6);
  crypto.getRandomValues(bytes);
  let code = '';
  for (let i = 0; i < 6; i++) {
    code += INVITE_CHARS[bytes[i] % INVITE_CHARS.length];
  }
  return code;
}

export function generateId(length = 16): string {
  const bytes = new Uint8Array(length);
  crypto.getRandomValues(bytes);
  let id = '';
  for (let i = 0; i < length; i++) {
    id += NANOID_CHARS[bytes[i] % NANOID_CHARS.length];
  }
  return id;
}

function base64UrlEncode(strOrBuffer: string | ArrayBuffer): string {
  let base64: string;
  if (typeof strOrBuffer === 'string') {
    const bytes = new TextEncoder().encode(strOrBuffer);
    let binary = '';
    for (let i = 0; i < bytes.byteLength; i++) {
      binary += String.fromCharCode(bytes[i]);
    }
    base64 = btoa(binary);
  } else {
    const bytes = new Uint8Array(strOrBuffer);
    let binary = '';
    for (let i = 0; i < bytes.byteLength; i++) {
      binary += String.fromCharCode(bytes[i]);
    }
    base64 = btoa(binary);
  }
  return base64.replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function base64UrlDecode(str: string): string {
  let base64 = str.replace(/-/g, '+').replace(/_/g, '/');
  while (base64.length % 4) {
    base64 += '=';
  }
  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return new TextDecoder().decode(bytes);
}

async function getHmacKey(secret: string): Promise<CryptoKey> {
  const keyData = new TextEncoder().encode(secret);
  return crypto.subtle.importKey(
    'raw',
    keyData,
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign', 'verify']
  );
}

export async function signJwt(
  payload: Record<string, unknown>,
  secret: string,
  expiresInSeconds: number
): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const fullPayload = {
    ...payload,
    iat: now,
    exp: now + expiresInSeconds,
  };

  const header = { alg: 'HS256', typ: 'JWT' };
  const encodedHeader = base64UrlEncode(JSON.stringify(header));
  const encodedPayload = base64UrlEncode(JSON.stringify(fullPayload));
  const dataToSign = `${encodedHeader}.${encodedPayload}`;

  const key = await getHmacKey(secret);
  const signatureBuffer = await crypto.subtle.sign(
    'HMAC',
    key,
    new TextEncoder().encode(dataToSign)
  );

  const encodedSignature = base64UrlEncode(signatureBuffer);
  return `${dataToSign}.${encodedSignature}`;
}

export async function verifyJwt<T = any>(token: string, secret: string): Promise<T> {
  if (!token || typeof token !== 'string') {
    throw new Error('Token is missing or invalid');
  }

  const parts = token.split('.');
  if (parts.length !== 3) {
    throw new Error('Invalid JWT format');
  }

  const [encodedHeader, encodedPayload, encodedSignature] = parts;
  const dataToVerify = `${encodedHeader}.${encodedPayload}`;

  const key = await getHmacKey(secret);

  // Decode signature to binary buffer
  let sigBase64 = encodedSignature.replace(/-/g, '+').replace(/_/g, '/');
  while (sigBase64.length % 4) {
    sigBase64 += '=';
  }
  const sigBinary = atob(sigBase64);
  const sigBytes = new Uint8Array(sigBinary.length);
  for (let i = 0; i < sigBinary.length; i++) {
    sigBytes[i] = sigBinary.charCodeAt(i);
  }

  const isValid = await crypto.subtle.verify(
    'HMAC',
    key,
    sigBytes,
    new TextEncoder().encode(dataToVerify)
  );

  if (!isValid) {
    throw new Error('Invalid JWT signature');
  }

  const payloadJson = base64UrlDecode(encodedPayload);
  const payload = JSON.parse(payloadJson) as T & { exp?: number };

  if (payload.exp && typeof payload.exp === 'number') {
    const now = Math.floor(Date.now() / 1000);
    if (now > payload.exp) {
      throw new Error('JWT token expired');
    }
  }

  return payload;
}
