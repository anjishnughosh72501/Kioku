const http = require('http');
const WebSocket = require('ws');
const jwt = require('jsonwebtoken');
const { createApp } = require('../server');
const { setupSignaling } = require('../services/signalService');

describe('WebRTC Signaling Isolation & Security Invariants', () => {
  let server;
  let port;
  const SECRET = 'test-secret-isolation-999';

  beforeAll((done) => {
    process.env.JWT_SECRET = SECRET;
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

  test('Rejects join if token groupId does not match albumId (IDOR prevention)', (done) => {
    const token = jwt.sign(
      { userId: 'eve', groupId: 'album_eve', name: 'Eve' },
      SECRET
    );

    const ws = new WebSocket(`ws://localhost:${port}/signal?token=${token}`);

    ws.on('open', () => {
      ws.send(
        JSON.stringify({
          type: 'join',
          albumId: 'album_alice_private', // Eve trying to join Alice's private album
          deviceId: 'device_eve_1',
        })
      );
    });

    ws.on('close', (code, reason) => {
      expect(code).toBe(4003);
      done();
    });
  });

  test('Signaling messages in Room A never leak to Room B', (done) => {
    const tokenA = jwt.sign(
      { userId: 'user_a', groupId: 'room_a', name: 'Alice' },
      SECRET
    );
    const tokenB = jwt.sign(
      { userId: 'user_b', groupId: 'room_b', name: 'Bob' },
      SECRET
    );

    const wsA = new WebSocket(`ws://localhost:${port}/signal?token=${tokenA}`);
    const wsB = new WebSocket(`ws://localhost:${port}/signal?token=${tokenB}`);

    let wsAReady = false;
    let wsBReady = false;

    function onConnected() {
      if (wsAReady && wsBReady) {
        // wsA joins room_a
        wsA.send(
          JSON.stringify({
            type: 'join',
            albumId: 'room_a',
            deviceId: 'dev_a',
          })
        );
        // wsB joins room_b
        wsB.send(
          JSON.stringify({
            type: 'join',
            albumId: 'room_b',
            deviceId: 'dev_b',
          })
        );
      }
    }

    wsA.on('open', () => {
      wsAReady = true;
      onConnected();
    });

    wsB.on('open', () => {
      wsBReady = true;
      onConnected();
    });

    let bobGotLeak = false;

    wsB.on('message', (data) => {
      const msg = JSON.parse(data.toString());
      if (msg.type === 'signal' && msg.fromDeviceId === 'dev_a') {
        bobGotLeak = true;
      }
    });

    wsA.on('message', (data) => {
      const msg = JSON.parse(data.toString());
      if (msg.type === 'room-peers') {
        // Now wsA sends signal meant for dev_b
        wsA.send(
          JSON.stringify({
            type: 'signal',
            targetDeviceId: 'dev_b',
            payload: { sdp: 'secret-offer-from-a' },
          })
        );

        setTimeout(() => {
          expect(bobGotLeak).toBe(false);
          wsA.close();
          wsB.close();
          done();
        }, 150);
      }
    });
  });

  test('Rejects connection when allowGuest query param is provided without valid token', (done) => {
    const ws = new WebSocket(`ws://localhost:${port}/signal?allowGuest=true`);
    ws.on('error', () => {
      // 401 Unauthorized expected
      done();
    });
  });
});
