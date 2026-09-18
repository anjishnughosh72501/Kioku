const http = require('http');
const WebSocket = require('ws');
const jwt = require('jsonwebtoken');
const { createApp } = require('../server');
const { setupSignaling } = require('../services/signalService');

describe('WebRTC Signaling Service', () => {
  let server;
  let port;
  let validToken;

  beforeAll((done) => {
    process.env.JWT_SECRET = 'test-secret-mesh';
    validToken = jwt.sign(
      { userId: 'user_1', groupId: 'album_vacation', name: 'Alice' },
      process.env.JWT_SECRET
    );

    const app = createApp();
    server = http.createServer(app);
    setupSignaling(server);

    server.listen(0, () => {
      port = server.address().port;
      done();
    });
  });

  afterAll((done) => {
    server.close(done);
  });

  test('Rejects connection without token', (done) => {
    const ws = new WebSocket(`ws://localhost:${port}/signal`);
    ws.on('error', () => {
      // Expected error due to 401 Unauthorized
      done();
    });
  });

  test('Connects with token and exchanges signaling messages between peers', (done) => {
    const ws1 = new WebSocket(`ws://localhost:${port}/signal?token=${validToken}`);
    const ws2 = new WebSocket(`ws://localhost:${port}/signal?token=${validToken}`);

    let ws1Connected = false;
    let ws2Connected = false;

    function checkReady() {
      if (ws1Connected && ws2Connected) {
        ws1.send(
          JSON.stringify({
            type: 'join',
            albumId: 'album_vacation',
            deviceId: 'device_phone_1',
          })
        );
      }
    }

    ws1.on('open', () => {
      ws1Connected = true;
      checkReady();
    });

    ws2.on('open', () => {
      ws2Connected = true;
      checkReady();
    });

    ws1.on('message', (data) => {
      const msg = JSON.parse(data.toString());
      if (msg.type === 'room-peers') {
        // ws1 joined, now join ws2
        ws2.send(
          JSON.stringify({
            type: 'join',
            albumId: 'album_vacation',
            deviceId: 'device_phone_2',
          })
        );
      }
    });

    ws2.on('message', (data) => {
      const msg = JSON.parse(data.toString());
      if (msg.type === 'room-peers') {
        // ws2 is in room, now send offer from ws1 to ws2
        ws1.send(
          JSON.stringify({
            type: 'signal',
            targetDeviceId: 'device_phone_2',
            payload: { sdp: 'dummy-sdp-offer' },
          })
        );
      } else if (msg.type === 'signal') {
        // ws2 received signal from ws1
        expect(msg.fromDeviceId).toBe('device_phone_1');
        expect(msg.payload.sdp).toBe('dummy-sdp-offer');

        ws1.close();
        ws2.close();
        done();
      }
    });
  });
});
