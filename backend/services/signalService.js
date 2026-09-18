// services/signalService.js
// Lightweight WebRTC signaling relay for P2P mesh photo replication.
// Transports ONLY session descriptions (SDP) and ICE candidates.
// NEVER touches photo bytes.

const WebSocket = require('ws');
const jwt = require('jsonwebtoken');
const crypto = require('crypto');
let Redis = null;
try {
  Redis = require('ioredis');
} catch (_) {}

/**
 * In-memory signaling store for single-instance deployments.
 */
class MemorySignalStore {
  constructor() {
    this.rooms = new Map(); // albumId -> Map<deviceId, ws>
  }

  join(albumId, deviceId, ws) {
    if (!this.rooms.has(albumId)) {
      this.rooms.set(albumId, new Map());
    }
    const room = this.rooms.get(albumId);
    room.set(deviceId, ws);
  }

  getPeers(albumId, excludeDeviceId) {
    if (!this.rooms.has(albumId)) return [];
    return Array.from(this.rooms.get(albumId).keys()).filter((id) => id !== excludeDeviceId);
  }

  getPeerSocket(albumId, deviceId) {
    if (!this.rooms.has(albumId)) return null;
    return this.rooms.get(albumId).get(deviceId) || null;
  }

  getRoomSockets(albumId) {
    if (!this.rooms.has(albumId)) return [];
    return Array.from(this.rooms.get(albumId).values());
  }

  leave(albumId, deviceId) {
    if (!this.rooms.has(albumId)) return;
    const room = this.rooms.get(albumId);
    room.delete(deviceId);
    if (room.size === 0) {
      this.rooms.delete(albumId);
    }
  }

  getRoomCount() {
    return this.rooms.size;
  }

  publishSignal(albumId, fromDeviceId, targetDeviceId, payload) {}
  publishPeerJoined(albumId, deviceId) {}
  publishPeerLeft(albumId, deviceId) {}
  async close() {}
}

/**
 * Multi-instance adapter with Redis Pub/Sub (P2-12).
 * Enables horizontal scaling with Redis Pub/Sub when REDIS_URL is configured.
 * Automatically falls back to MemorySignalStore if Redis is offline or fails.
 */
class DistributedSignalStore extends MemorySignalStore {
  constructor(redisUrl) {
    super();
    this.redisUrl = redisUrl;
    this.instanceId = crypto.randomUUID ? crypto.randomUUID() : `inst_${Date.now()}_${Math.random()}`;
    this.isReady = false;
    this.channel = 'kioku:signal:events';

    if (!Redis || !redisUrl) {
      return;
    }

    try {
      this.pub = new Redis(redisUrl, {
        lazyConnect: true,
        maxRetriesPerRequest: 1,
        retryStrategy: (times) => (times > 3 ? null : 500),
      });

      this.sub = new Redis(redisUrl, {
        lazyConnect: true,
        maxRetriesPerRequest: 1,
        retryStrategy: (times) => (times > 3 ? null : 500),
      });

      this.pub.on('error', () => {
        this.isReady = false;
      });

      this.sub.on('error', () => {
        this.isReady = false;
      });

      Promise.all([this.pub.connect(), this.sub.connect()])
        .then(() => {
          this.isReady = true;
          this.sub.subscribe(this.channel, (err) => {
            if (err) this.isReady = false;
          });
          this.sub.on('message', (chan, messageStr) => {
            if (chan === this.channel) {
              this._handleRedisMessage(messageStr);
            }
          });
        })
        .catch(() => {
          this.isReady = false;
        });
    } catch (_) {
      this.isReady = false;
    }
  }

  _handleRedisMessage(messageStr) {
    try {
      const msg = JSON.parse(messageStr);
      if (!msg || msg.originInstanceId === this.instanceId) return;

      const { type, albumId, fromDeviceId, targetDeviceId, payload, deviceId } = msg;

      if (type === 'signal') {
        const targetWs = this.getPeerSocket(albumId, targetDeviceId);
        if (targetWs && targetWs.readyState === WebSocket.OPEN) {
          targetWs.send(
            JSON.stringify({
              type: 'signal',
              fromDeviceId,
              payload,
            })
          );
        }
      } else if (type === 'peer-joined') {
        const roomSockets = this.getRoomSockets(albumId);
        for (const peerWs of roomSockets) {
          if (peerWs.readyState === WebSocket.OPEN) {
            peerWs.send(
              JSON.stringify({
                type: 'peer-joined',
                albumId,
                deviceId,
              })
            );
          }
        }
      } else if (type === 'peer-left') {
        const roomSockets = this.getRoomSockets(albumId);
        for (const peerWs of roomSockets) {
          if (peerWs.readyState === WebSocket.OPEN) {
            peerWs.send(
              JSON.stringify({
                type: 'peer-left',
                albumId,
                deviceId,
              })
            );
          }
        }
      }
    } catch (_) {}
  }

  publishSignal(albumId, fromDeviceId, targetDeviceId, payload) {
    if (this.isReady && this.pub) {
      try {
        this.pub.publish(
          this.channel,
          JSON.stringify({
            originInstanceId: this.instanceId,
            type: 'signal',
            albumId,
            fromDeviceId,
            targetDeviceId,
            payload,
          })
        ).catch(() => {});
      } catch (_) {}
    }
  }

  publishPeerJoined(albumId, deviceId) {
    if (this.isReady && this.pub) {
      try {
        this.pub.publish(
          this.channel,
          JSON.stringify({
            originInstanceId: this.instanceId,
            type: 'peer-joined',
            albumId,
            deviceId,
          })
        ).catch(() => {});
      } catch (_) {}
    }
  }

  publishPeerLeft(albumId, deviceId) {
    if (this.isReady && this.pub) {
      try {
        this.pub.publish(
          this.channel,
          JSON.stringify({
            originInstanceId: this.instanceId,
            type: 'peer-left',
            albumId,
            deviceId,
          })
        ).catch(() => {});
      } catch (_) {}
    }
  }

  async close() {
    this.isReady = false;
    try {
      if (this.pub) await this.pub.quit();
    } catch (_) {}
    try {
      if (this.sub) await this.sub.quit();
    } catch (_) {}
  }
}

function createSignalStore() {
  if (process.env.REDIS_URL) {
    return new DistributedSignalStore(process.env.REDIS_URL);
  }
  return new MemorySignalStore();
}

function setupSignaling(server, customStore = null) {
  const wss = new WebSocket.Server({ noServer: true });
  const store = customStore || createSignalStore();

  server.on('upgrade', (request, socket, head) => {
    const url = new URL(request.url, 'http://' + request.headers.host);
    if (url.pathname !== '/signal') {
      return;
    }

    const token = url.searchParams.get('token');
    if (!token) {
      socket.write('HTTP/1.1 401 Unauthorized\r\n\r\n');
      socket.destroy();
      return;
    }

    if (!process.env.JWT_SECRET) {
      socket.write('HTTP/1.1 500 Internal Server Error\r\n\r\n');
      socket.destroy();
      return;
    }

    try {
      const decoded = jwt.verify(token, process.env.JWT_SECRET);
      request.user = decoded;
    } catch (err) {
      socket.write('HTTP/1.1 401 Unauthorized\r\n\r\n');
      socket.destroy();
      return;
    }

    wss.handleUpgrade(request, socket, head, (ws) => {
      wss.emit('connection', ws, request);
    });
  });

  wss.on('connection', (ws, request) => {
    let currentAlbumId = null;
    let currentDeviceId = null;

    ws.on('message', (data) => {
      try {
        const msg = JSON.parse(data.toString());
        const { type, albumId, deviceId, targetDeviceId, payload } = msg;

        switch (type) {
          case 'join': {
            // Check group membership authorization to prevent IDOR
            const authorizedGroup = request.user && (request.user.groupId || request.user.albumId);
            if (authorizedGroup && authorizedGroup !== albumId) {
              ws.send(
                JSON.stringify({
                  type: 'error',
                  message: 'Forbidden: unauthorized album membership',
                })
              );
              ws.close(4003, 'Forbidden');
              return;
            }

            currentAlbumId = albumId;
            currentDeviceId = deviceId;

            store.join(albumId, deviceId, ws);

            // Notify joining peer of existing peers in the album room
            const peers = store.getPeers(albumId, deviceId);
            ws.send(
              JSON.stringify({
                type: 'room-peers',
                albumId,
                peers,
              })
            );

            // Broadcast join notification to existing local peers
            const roomSockets = store.getRoomSockets(albumId);
            for (const peerWs of roomSockets) {
              if (peerWs !== ws && peerWs.readyState === WebSocket.OPEN) {
                peerWs.send(
                  JSON.stringify({
                    type: 'peer-joined',
                    albumId,
                    deviceId,
                  })
                );
              }
            }

            // Broadcast across Redis cluster if distributed store
            store.publishPeerJoined(albumId, deviceId);
            break;
          }

          case 'signal': {
            // Relay offer, answer, or candidate to target peer
            if (currentAlbumId) {
              const targetWs = store.getPeerSocket(currentAlbumId, targetDeviceId);
              if (targetWs && targetWs.readyState === WebSocket.OPEN) {
                targetWs.send(
                  JSON.stringify({
                    type: 'signal',
                    fromDeviceId: currentDeviceId,
                    payload,
                  })
                );
              }
              // Also relay to remote cluster nodes
              store.publishSignal(currentAlbumId, currentDeviceId, targetDeviceId, payload);
            }
            break;
          }

          case 'leave': {
            _handleLeave();
            break;
          }
        }
      } catch (_) {}
    });

    function _handleLeave() {
      if (currentAlbumId && currentDeviceId) {
        store.leave(currentAlbumId, currentDeviceId);

        const roomSockets = store.getRoomSockets(currentAlbumId);
        for (const peerWs of roomSockets) {
          if (peerWs.readyState === WebSocket.OPEN) {
            peerWs.send(
              JSON.stringify({
                type: 'peer-left',
                albumId: currentAlbumId,
                deviceId: currentDeviceId,
              })
            );
          }
        }

        // Broadcast leave event across Redis cluster
        store.publishPeerLeft(currentAlbumId, currentDeviceId);
      }
    }

    ws.on('close', _handleLeave);
    ws.on('error', _handleLeave);
  });

  return wss;
}

module.exports = { setupSignaling, MemorySignalStore, DistributedSignalStore, createSignalStore };
