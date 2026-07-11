import * as ed from '@noble/ed25519';
import { sha256, sha512 } from '@noble/hashes/sha2.js';
import * as Crypto from 'expo-crypto';

// Ed25519 signing is deterministic (no RNG), it only needs a SHA-512 hook.
// Wire that up once so ed.sign / ed.getPublicKey work synchronously.
ed.etc.sha512Sync = (...m) => sha512(ed.etc.concatBytes(...m));

export function utf8ToBytes(s: string): Uint8Array {
  const out = new Uint8Array(s.length * 3);
  let n = 0;
  for (let i = 0; i < s.length; i++) {
    let c = s.charCodeAt(i);
    if (c < 0x80) out[n++] = c;
    else if (c < 0x800) {
      out[n++] = 0xc0 | (c >> 6);
      out[n++] = 0x80 | (c & 0x3f);
    } else if (c >= 0xd800 && c <= 0xdbff) {
      c = 0x10000 + ((c & 0x3ff) << 10) + (s.charCodeAt(++i) & 0x3ff);
      out[n++] = 0xf0 | (c >> 18);
      out[n++] = 0x80 | ((c >> 12) & 0x3f);
      out[n++] = 0x80 | ((c >> 6) & 0x3f);
      out[n++] = 0x80 | (c & 0x3f);
    } else {
      out[n++] = 0xe0 | (c >> 12);
      out[n++] = 0x80 | ((c >> 6) & 0x3f);
      out[n++] = 0x80 | (c & 0x3f);
    }
  }
  return out.slice(0, n);
}

export function bytesToHex(b: Uint8Array): string {
  let s = '';
  for (let i = 0; i < b.length; i++) s += b[i].toString(16).padStart(2, '0');
  return s;
}

export function hexToBytes(hex: string): Uint8Array {
  const b = new Uint8Array(hex.length / 2);
  for (let i = 0; i < b.length; i++) b[i] = parseInt(hex.substr(i * 2, 2), 16);
  return b;
}

const B64 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';

// base64url with no padding — matches the Swift DeviceIdentity.base64url().
export function bytesToBase64url(bytes: Uint8Array): string {
  let out = '';
  for (let i = 0; i < bytes.length; i += 3) {
    const a = bytes[i];
    const b = i + 1 < bytes.length ? bytes[i + 1] : 0;
    const c = i + 2 < bytes.length ? bytes[i + 2] : 0;
    out += B64[a >> 2];
    out += B64[((a & 3) << 4) | (b >> 4)];
    out += i + 1 < bytes.length ? B64[((b & 15) << 2) | (c >> 6)] : '';
    out += i + 2 < bytes.length ? B64[c & 63] : '';
  }
  return out.replace(/\+/g, '-').replace(/\//g, '_');
}

export function generatePrivateKey(): Uint8Array {
  return Crypto.getRandomBytes(32);
}

export function getPublicKey(priv: Uint8Array): Uint8Array {
  return ed.getPublicKey(priv);
}

export function sign(message: string, priv: Uint8Array): Uint8Array {
  return ed.sign(utf8ToBytes(message), priv);
}

export function sha256Hex(bytes: Uint8Array): string {
  return bytesToHex(sha256(bytes));
}
