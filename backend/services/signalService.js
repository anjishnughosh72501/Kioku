// services/signalService.js
// Lightweight WebRTC signaling relay for P2P mesh photo replication.
// Transports ONLY session descriptions (SDP) and ICE candidates.
// NEVER touches photo bytes.

const WebSocket = require('ws');
const jwt = require('jsonwebtoken');

function setupSignaling(server) {
  const wss = new WebSocket.Server({ noServer: true });

  // Map of albumId -> Map of deviceId -> WebSocket client
  const rooms = new Map();

  server.on('upgrade', (request, socket, head) => {
    const url = new URL(request.url, `http://${request.headers.host}`);
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

            if (!rooms.has(albumId)) {
              rooms.set(albumId, new Map());
            }
            const room = rooms.get(albumId);
            room.set(deviceId, ws);

            // Notify existing peers
            const peers = Array.from(room.keys()).filter((id) => id !== deviceId);
            ws.send(
              JSON.stringify({
                type: 'room-peers',
                albumId,
                peers,
              })
            );

            for (const [peerId, peerWs] of room.entries()) {
              if (peerId !== deviceId && peerWs.readyState === WebSocket.OPEN) {
                peerWs.send(
                  JSON.stringify({
                    type: 'peer-joined',
                    albumId,
                    deviceId,
                  })
                );
              }
            }
            break;
          }

          case 'signal': {
            // Relay offer, answer, or candidate to target peer
            if (currentAlbumId && rooms.has(currentAlbumId)) {
              const room = rooms.get(currentAlbumId);
              const targetWs = room.get(targetDeviceId);
              if (targetWs && targetWs.readyState === WebSocket.OPEN) {
                targetWs.send(
                  JSON.stringify({
                    type: 'signal',
                    fromDeviceId: currentDeviceId,
                    payload,
                  })
                );
              }
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
      if (currentAlbumId && currentDeviceId && rooms.has(currentAlbumId)) {
        const room = rooms.get(currentAlbumId);
        room.remove ? room.remove(currentDeviceId) : room.delete(currentDeviceId);

        for (const peerWs of room.values()) {
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
        if (room.size === 0) {
          rooms.delete(currentAlbumId);
        }
      }
    }

    ws.on('close', _handleLeave);
    ws.on('error', _handleLeave);
  });

  return wss;
}

module.exports = { setupSignaling };
