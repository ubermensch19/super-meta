// Minimal mock of an OpenClaw/Hermes gateway for testing the RN GatewayClient.
// Speaks the real v3 protocol: sends connect.challenge, VERIFIES the client's
// Ed25519 signature, accepts the node, then invokes device.info to prove the
// round-trip. Run: node testing/mock-gateway.mjs   (listens on ws://0.0.0.0:18789)
import { WebSocketServer } from 'ws';
import * as ed from '@noble/ed25519';
import { sha512, sha256 } from '@noble/hashes/sha2.js';

ed.etc.sha512Sync = (...m) => sha512(ed.etc.concatBytes(...m));

const PORT = 18789;
const b64urlToBytes = (s) => {
  s = s.replace(/-/g, '+').replace(/_/g, '/');
  while (s.length % 4) s += '=';
  return new Uint8Array(Buffer.from(s, 'base64'));
};
const hex = (b) => Buffer.from(b).toString('hex');
const log = (...a) => console.log('[mock-gateway]', ...a);

const wss = new WebSocketServer({ host: '0.0.0.0', port: PORT });
log(`listening on ws://0.0.0.0:${PORT}`);

wss.on('connection', (ws) => {
  const nonce = 'nonce-' + Math.random().toString(36).slice(2);
  log('client connected → sending challenge', nonce);
  ws.send(JSON.stringify({ type: 'event', event: 'connect.challenge', payload: { nonce } }));

  ws.on('message', (raw) => {
    let f;
    try { f = JSON.parse(String(raw)); } catch { return; }

    if (f.type === 'req' && f.method === 'connect') {
      const p = f.params;
      const d = p.device;
      const msg = [
        'v3', d.id, p.client.id, p.client.mode, p.role,
        p.scopes.join(','), String(d.signedAt), p.auth.token, d.nonce, d.platform, d.deviceFamily,
      ].join('|');

      const pub = b64urlToBytes(d.publicKey);
      const sig = b64urlToBytes(d.signature);
      const sigOK = ed.verify(sig, new TextEncoder().encode(msg), pub);
      const idOK = hex(sha256(pub)) === d.id;

      log('connect from node', p.client.name, '| signature', sigOK ? 'VALID ✅' : 'INVALID ❌', '| deviceID', idOK ? 'matches ✅' : 'mismatch ❌');
      if (!sigOK || !idOK) {
        ws.send(JSON.stringify({ type: 'res', id: f.id, ok: false, error: { code: 'BAD_SIG', message: 'signature/deviceID check failed' } }));
        return;
      }
      ws.send(JSON.stringify({ type: 'res', id: f.id, ok: true, payload: {} }));
      log('→ node accepted; invoking device.info to test round-trip');
      const invokeId = 'inv-1';
      ws.send(JSON.stringify({ type: 'req', id: invokeId, method: 'node.invoke', params: { command: 'device.info', params: {} } }));
      return;
    }

    if (f.type === 'res' && f.id === 'inv-1') {
      log('device.info response:', JSON.stringify(f.payload), f.ok ? '✅' : '❌');
      log('ROUND-TRIP OK — the RN client connected, signed, and answered a command.');
      return;
    }

    if (f.type === 'req' && f.method === 'ping') {
      ws.send(JSON.stringify({ type: 'res', id: f.id, ok: true, payload: {} }));
    }
  });

  ws.on('close', () => log('client disconnected'));
});
