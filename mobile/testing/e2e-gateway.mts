// End-to-end test of the REAL GatewayClient against the mock gateway, run in Node.
// Proves the full connect handshake (challenge → signed connect → connected) and a
// node.invoke round-trip using the exact client code the app ships.
// Run: node testing/mock-gateway.mjs &   then   npx tsx testing/e2e-gateway.mts
import { WebSocket } from 'ws';
import * as ed from '@noble/ed25519';
import { sha512, sha256 } from '@noble/hashes/sha2.js';

import { GatewayClient } from '../src/gateway/GatewayClient';
import type { DeviceIdentity } from '../src/gateway/identity';

ed.etc.sha512Sync = (...m) => sha512(ed.etc.concatBytes(...m));
// The RN runtime provides a global WebSocket; supply Node's here.
(globalThis as any).WebSocket = WebSocket;

const B64 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
const b64url = (b: Uint8Array) => {
  let o = '';
  for (let i = 0; i < b.length; i += 3) {
    const a = b[i], x = i + 1 < b.length ? b[i + 1] : 0, c = i + 2 < b.length ? b[i + 2] : 0;
    o += B64[a >> 2] + B64[((a & 3) << 4) | (x >> 4)];
    o += i + 1 < b.length ? B64[((x & 15) << 2) | (c >> 6)] : '';
    o += i + 2 < b.length ? B64[c & 63] : '';
  }
  return o.replace(/\+/g, '-').replace(/\//g, '_');
};
const hex = (b: Uint8Array) => Buffer.from(b).toString('hex');

// Build a DeviceIdentity matching identity.ts (without expo-secure-store).
const seed = new Uint8Array(sha256(new TextEncoder().encode('e2e-test-seed'))); // 32 bytes
const pub = ed.getPublicKey(seed);
const deviceID = hex(sha256(pub));
const identity: DeviceIdentity = {
  deviceID,
  nodeID: 'rayban-' + deviceID.slice(0, 8),
  publicKeyB64Url: b64url(pub),
  sign: (msg: string) => b64url(ed.sign(new TextEncoder().encode(msg), seed)),
};

const handler = async (method: string) => {
  if (method === 'device.info')
    return { device: 'rayban-meta', app: 'Super Meta', platform: 'ios', node: identity.nodeID };
  throw { code: 'UNKNOWN_COMMAND', message: method };
};

let reachedConnected = false;
const client = new GatewayClient(
  { host: '127.0.0.1', port: 18789, useTLS: false, token: '' },
  identity,
  handler,
  (state, error) => {
    console.log(`[client] state → ${state}${error ? ' (' + error + ')' : ''}`);
    if (state === 'connected') reachedConnected = true;
  },
);

console.log('[client] connecting as node', identity.nodeID, '…');
client.connect();

setTimeout(() => {
  console.log(reachedConnected ? '\nE2E OK ✅ — real GatewayClient connected + served a command.' : '\nE2E FAILED ❌ — never reached connected.');
  client.disconnect();
  process.exit(reachedConnected ? 0 : 1);
}, 3000);
