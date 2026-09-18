# Kioku WebRTC Signaling & Horizontal Scaling Architecture (P2-12)

**Protocol:** WebSocket (ws:// / wss://) over /signal  
**Payload Type:** SDP Session Descriptions & ICE Candidates only (zero photo bytes)

---

## 1. Role in Kioku Mesh Replication

Kioku includes an offline-capable, peer-to-peer mesh storage engine (mesh_storage.dart). When devices belonging to the same album are on different networks or behind NATs:
1. Devices connect to wss://<backend>/signal?token=<jwt>.
2. The signaling server exchanges WebSockets messages:
   - join: Authenticates the user's membership in the target lbumId (preventing IDOR).
   - signal: Relays WebRTC SDP offers, answers, and ICE candidates between specific deviceId pairs.
3. Once the WebRTC DataChannel connects, devices replicate encrypted photo blobs directly peer-to-peer.
4. The signaling server never sees, buffers, or stores photo bytes.

---

## 2. Pluggable Signaling Stores

services/signalService.js provides an extensible architecture supporting both single-server and multi-instance distributed deployments:

### Single-Instance Mode (MemorySignalStore)
- Default out-of-the-box configuration.
- Maintains in-memory Map<albumId, Map<deviceId, WebSocket>>.
- Zero external dependencies. Ideal for self-hosting on a single VPS or container.

### Multi-Instance Distributed Mode (DistributedSignalStore)
- Activated automatically when REDIS_URL is defined in the environment.
- Utilizes Redis Pub/Sub channels (kioku:signal:<albumId>):
  - When Device A on Node 1 sends a signal to Device B on Node 2:
    1. Node 1 publishes { targetDeviceId, payload } to the Redis channel.
    2. Node 2 receives the Redis broadcast, matches Device B on its local socket map, and forwards the packet.
- Allows horizontal scaling of signaling servers behind a standard load balancer (e.g., AWS ALB, Cloudflare, NGINX).

---

## 3. Deployment Configuration

`ash
# Single Instance
PORT=3000
JWT_SECRET=your_strong_secret_key

# Distributed Cluster (Multi-Node)
PORT=3000
JWT_SECRET=your_strong_secret_key
REDIS_URL=redis://redis-cluster.internal:6379
`
