// src/routes/signaling.ts
// Lightweight WebRTC signaling relay for P2P mesh photo replication on Cloudflare Workers.
// Transports ONLY session descriptions (SDP) and ICE candidates. NEVER touches photo bytes.

import { Hono } from 'hono';
import { AppEnv } from '../types';
import { verifyJwt } from '../crypto';

export const signalingApp = new Hono<AppEnv>();

// In-isolate signaling rooms map: albumId -> Map<deviceId, WebSocket>
const rooms = new Map<string, Map<string, WebSocket>>();

function joinRoom(albumId: string, deviceId: string, ws: WebSocket) {
  if (!rooms.has(albumId)) {
    rooms.set(albumId, new Map());
  }
  rooms.get(albumId)!.set(deviceId, ws);
}

function getPeers(albumId: string, excludeDeviceId: string): string[] {
  if (!rooms.has(albumId)) return [];
  return Array.from(rooms.get(albumId)!.keys()).filter((id) => id !== excludeDeviceId);
}

function getPeerSocket(albumId: string, deviceId: string): WebSocket | null {
  if (!rooms.has(albumId)) return null;
  return rooms.get(albumId)!.get(deviceId) || null;
}

function getRoomSockets(albumId: string): WebSocket[] {
  if (!rooms.has(albumId)) return [];
  return Array.from(rooms.get(albumId)!.values());
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

  const secret = c.env.JWT_SECRET || 'default-dev-secret-change-in-production-please';
  let decodedUser: any;
  try {
    decodedUser = await verifyJwt(token, secret);
  } catch (err) {
    return c.text('Unauthorized: invalid token', 401);
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

  server.addEventListener('message', (event) => {
    try {
      const data = typeof event.data === 'string' ? event.data : new TextDecoder().decode(event.data as ArrayBuffer);
      const msg = JSON.parse(data);
      const { type, albumId, deviceId, targetDeviceId, payload } = msg;

      switch (type) {
        case 'join': {
          const authorizedGroup = decodedUser && (decodedUser.groupId || decodedUser.albumId);
          if (authorizedGroup && authorizedGroup !== albumId) {
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
          joinRoom(albumId, deviceId, server);

          // Return room peers
          const peers = getPeers(albumId, deviceId);
          server.send(
            JSON.stringify({
              type: 'room-peers',
              albumId,
              peers,
            })
          );

          // Broadcast peer-joined
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
            const targetWs = getPeerSocket(currentAlbumId, targetDeviceId);
            if (targetWs) {
              try {
                targetWs.send(
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
