import * as ed from '@noble/ed25519';
import { sha512, sha256 } from '@noble/hashes/sha2.js';
ed.etc.sha512Sync = (...m) => sha512(ed.etc.concatBytes(...m));

const B64='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
function b64url(bytes){let o='';for(let i=0;i<bytes.length;i+=3){const a=bytes[i],b=i+1<bytes.length?bytes[i+1]:0,c=i+2<bytes.length?bytes[i+2]:0;o+=B64[a>>2];o+=B64[((a&3)<<4)|(b>>4)];o+=i+1<bytes.length?B64[((b&15)<<2)|(c>>6)]:'';o+=i+2<bytes.length?B64[c&63]:'';}return o.replace(/\+/g,'-').replace(/\//g,'_');}
function b64urlToBytes(s){s=s.replace(/-/g,'+').replace(/_/g,'/');while(s.length%4)s+='=';return new Uint8Array(Buffer.from(s,'base64'));}
const hex=b=>Buffer.from(b).toString('hex');

// --- CLIENT side (mirrors crypto.ts / GatewayClient.sendConnect) ---
const seed = new Uint8Array(32).fill(7);              // deterministic test key
const pub = ed.getPublicKey(seed);
const deviceID = hex(sha256(pub));
const pubB64 = b64url(pub);
const nonce = 'test-nonce', signedAt = 1700000000000, token = '';
const msg = ['v3',deviceID,'metamod-ios','node','node','operator.read,operator.write',String(signedAt),token,nonce,'ios','rayban'].join('|');
const sigB64 = b64url(ed.sign(new TextEncoder().encode(msg), seed));

// --- SERVER side (mirrors mock-gateway verification) ---
const okSig = ed.verify(b64urlToBytes(sigB64), new TextEncoder().encode(msg), b64urlToBytes(pubB64));
const okId  = hex(sha256(b64urlToBytes(pubB64))) === deviceID;
console.log('deviceID       :', deviceID.slice(0,16)+'…');
console.log('signature b64url:', sigB64.slice(0,24)+'…');
console.log('signature VALID :', okSig);
console.log('deviceID matches:', okId);
console.log(okSig && okId ? 'CRYPTO PORT OK ✅' : 'CRYPTO PORT BROKEN ❌');
