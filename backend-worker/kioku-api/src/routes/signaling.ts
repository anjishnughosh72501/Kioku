// src/routes/signaling.ts
// Lightweight WebRTC signaling relay for P2P mesh photo replication on Cloudflare Workers.
// Transports ONLY session descriptions (SDP) and ICE candidates. NEVER touches photo bytes.
// Enforces canonical D1 album membership authorization (Section 17).

import { Hono } from 'hono';
import { AppEnv, AlbumMemberRow } from '../types';
import { verifyJwt, getJwtSecret } from '../crypto';

export const signalingApp = new Hono<AppEnv>();

// In-isolate signaling rooms map: albumId -> Map<deviceId, { ws: WebSocket, userCode: string }>
interface PeerInfo {
  ws: WebSocket;
  userCode: string;
}

const rooms = new Map<string, Map<string, PeerInfo>>();

function joinRoom(albumId: string, deviceId: string, ws: WebSocket, userCode: string) {
  if (!rooms.has(albumId)) {
    rooms.set(albumId, new Map());
  }
  rooms.get(albumId)!.set(deviceId, { ws, userCode });
}

function getPeers(albumId: string, excludeDeviceId: string): string[] {
  if (!rooms.has(albumId)) return [];
  return Array.from(rooms.get(albumId)!.keys()).filter((id) => id !== excludeDeviceId);
}

function getPeerInfo(albumId: string, deviceId: string): PeerInfo | null {
  if (!rooms.has(albumId)) return null;
  return rooms.get(albumId)!.get(deviceId) || null;
}

function getRoomSockets(albumId: string): WebSocket[] {
  if (!rooms.has(albumId)) return [];
  return Array.from(rooms.get(albumId)!.values()).map((p) => p.ws);
}

function leaveRoom(albumId: string, deviceId: string) {
  if (!rooms.has(albumId)) return;
  const room = rooms.get(albumId)!;
  room.delete(deviceId);
  if (room.size === 0) {
    rooms.delete(albumId);
  }
}

signalingApp.get('/', async (c) => {
  const upgradeHeader = c.req.header('Upgrade');
  if (!upgradeHeader || upgradeHeader.toLowerCase() !== 'websocket') {
    return c.text('Expected Upgrade: websocket', 426);
  }

  const token = c.req.query('token');
  if (!token) {
    return c.text('Unauthorized: missing token query param', 401);
  }

  const secret = getJwtSecret(c.env);
  let decodedUser: { friendCode?: string; userId?: string } | null = null;
  try {
    decodedUser = await verifyJwt(token, secret);
  } catch (_) {
    return c.text('Unauthorized: invalid token', 401);
  }

  const userCode = decodedUser?.friendCode || decodedUser?.userId;
  if (!userCode) {
    return c.text('Unauthorized: invalid token identity', 401);
  }

  const webSocketPair = new WebSocketPair();
  const [client, server] = Object.values(webSocketPair);

  server.accept();

  let currentAlbumId: string | null = null;
  let currentDeviceId: string | null = null;

  function broadcastLeave() {
    if (currentAlbumId && currentDeviceId) {
      leaveRoom(currentAlbumId, currentDeviceId);
      const roomSockets = getRoomSockets(currentAlbumId);
      for (const peerWs of roomSockets) {
        try {
          peerWs.send(
            JSON.stringify({
              type: 'peer-left',
              albumId: currentAlbumId,
              deviceId: currentDeviceId,
            })
          );
        } catch (_) {}
      }
      currentAlbumId = null;
      currentDeviceId = null;
    }
  }

  server.addEventListener('message', async (event) => {
    try {
      // Reject oversized messages (> 64KB) to prevent resource exhaustion
      const rawData = typeof event.data === 'string' ? event.data : new TextDecoder().decode(event.data as ArrayBuffer);
      if (rawData.length > 65536) {
        server.send(JSON.stringify({ type: 'error', message: 'Payload too large' }));
        return;
      }

      const msg = JSON.parse(rawData);
      const { type, albumId, deviceId, targetDeviceId, payload } = msg;

      switch (type) {
        case 'join': {
          if (!albumId || !deviceId) {
            server.send(JSON.stringify({ type: 'error', message: 'albumId and deviceId are required' }));
            return;
          }

          // Authorize through canonical D1 album_members table (Section 17)
          const member = await c.env.DB.prepare(
            `SELECT role, status FROM album_members WHERE album_id = ? AND user_id = ? AND status = 'active'`
          )
            .bind(albumId, userCode)
            .first<AlbumMemberRow>();

          if (!member) {
            server.send(
              JSON.stringify({
                type: 'error',
                message: 'Forbidden: unauthorized album membership',
              })
            );
            server.close(4003, 'Forbidden');
            return;
          }

          currentAlbumId = albumId;
          currentDeviceId = deviceId;
          joinRoom(albumId, deviceId, server, userCode);

          // Return existing peers in the room
          const peers = getPeers(albumId, deviceId);
          server.send(
            JSON.stringify({
              type: 'room-peers',
              albumId,
              peers,
            })
          );

          // Broadcast peer-joined to others
          const roomSockets = getRoomSockets(albumId);
          for (const peerWs of roomSockets) {
            if (peerWs !== server) {
              try {
                peerWs.send(
                  JSON.stringify({
                    type: 'peer-joined',
                    albumId,
                    deviceId,
                  })
                );
              } catch (_) {}
            }
          }
          break;
        }

        case 'signal': {
          if (currentAlbumId && targetDeviceId) {
            const targetPeer = getPeerInfo(currentAlbumId, targetDeviceId);
            if (targetPeer && targetPeer.ws) {
              try {
                targetPeer.ws.send(
                  JSON.stringify({
                    type: 'signal',
                    fromDeviceId: currentDeviceId,
                    payload,
                  })
                );
              } catch (_) {}
            }
          }
          break;
        }

        case 'leave': {
          broadcastLeave();
          break;
        }
      }
    } catch (_) {}
  });

  server.addEventListener('close', () => {
    broadcastLeave();
  });

  server.addEventListener('error', () => {
    broadcastLeave();
  });

  return new Response(null, {
    status: 101,
    webSocket: client,
  });
});
