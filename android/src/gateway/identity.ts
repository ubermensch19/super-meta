import * as SecureStore from 'expo-secure-store';

import {
  bytesToBase64url,
  generatePrivateKey,
  getPublicKey,
  hexToBytes,
  bytesToHex,
  sha256Hex,
  sign,
} from './crypto';

// Stable Ed25519 device identity, mirroring the native DeviceIdentity.
// The 32-byte private key is persisted in the Keychain via SecureStore.
const KEY_STORE = 'gateway_device_key';

export interface DeviceIdentity {
  deviceID: string; // hex(sha256(publicKey))
  nodeID: string; // "rayban-" + first 8 of deviceID
  publicKeyB64Url: string;
  sign: (message: string) => string; // base64url signature
}

function build(priv: Uint8Array): DeviceIdentity {
  const pub = getPublicKey(priv);
  const deviceID = sha256Hex(pub);
  return {
    deviceID,
    nodeID: 'rayban-' + deviceID.slice(0, 8),
    publicKeyB64Url: bytesToBase64url(pub),
    sign: (message: string) => bytesToBase64url(sign(message, priv)),
  };
}

/** Loads the persisted identity, generating and storing one on first run. */
export async function loadIdentity(): Promise<DeviceIdentity> {
  let hex = await SecureStore.getItemAsync(KEY_STORE);
  if (!hex) {
    const priv = generatePrivateKey();
    hex = bytesToHex(priv);
    await SecureStore.setItemAsync(KEY_STORE, hex);
  }
  return build(hexToBytes(hex));
}
