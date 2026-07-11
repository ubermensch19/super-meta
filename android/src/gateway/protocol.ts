// Wire protocol for the OpenClaw/Hermes gateway — a faithful TS port of
// GatewayProtocol.swift so this client talks to the same real gateways.

export type Frame =
  | { type: 'req'; id: string; method: string; params: Record<string, any> }
  | { type: 'res'; id: string; ok: boolean; payload?: Record<string, any>; error?: GatewayError }
  | { type: 'event'; event: string; payload: Record<string, any> };

export interface GatewayError {
  code: string;
  message: string;
}

export function encodeFrame(frame: Frame): string {
  return JSON.stringify(frame);
}

export function decodeFrame(data: string): Frame | null {
  let json: any;
  try {
    json = JSON.parse(data);
  } catch {
    return null;
  }
  switch (json?.type) {
    case 'req':
      if (typeof json.id !== 'string' || typeof json.method !== 'string') return null;
      return { type: 'req', id: json.id, method: json.method, params: json.params ?? {} };
    case 'res':
      if (typeof json.id !== 'string') return null;
      return {
        type: 'res',
        id: json.id,
        ok: json.ok === true,
        payload: json.payload,
        error: json.error
          ? { code: json.error.code ?? '', message: json.error.message ?? '' }
          : undefined,
      };
    case 'event':
      if (typeof json.event !== 'string') return null;
      return { type: 'event', event: json.event, payload: json.payload ?? {} };
    default:
      return null;
  }
}

// The v3 signed string the gateway expects in the connect request.
export function signedStringV3(args: {
  deviceID: string;
  clientID: string;
  clientMode: string;
  role: string;
  scopes: string[];
  signedAtMs: number;
  token: string;
  nonce: string;
  platform: string;
  deviceFamily: string;
}): string {
  return [
    'v3',
    args.deviceID,
    args.clientID,
    args.clientMode,
    args.role,
    args.scopes.join(','),
    String(args.signedAtMs),
    args.token,
    args.nonce,
    args.platform,
    args.deviceFamily,
  ].join('|');
}
