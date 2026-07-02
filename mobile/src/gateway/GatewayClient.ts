import type { DeviceIdentity } from './identity';
import { decodeFrame, encodeFrame, Frame, GatewayError, signedStringV3 } from './protocol';

export interface GatewayConfig {
  host: string;
  port: number;
  useTLS: boolean;
  token: string;
}

export const DEFAULT_CONFIG: GatewayConfig = {
  host: '127.0.0.1',
  port: 18789,
  useTLS: false,
  token: '',
};

export function configURL(c: GatewayConfig): string {
  const scheme = c.useTLS ? 'wss' : 'ws';
  const base = `${scheme}://${c.host}:${c.port}`;
  return c.token ? `${base}?token=${encodeURIComponent(c.token)}` : base;
}

export type ConnectionState =
  | 'disconnected'
  | 'connecting'
  | 'connected'
  | 'waitingForPairing'
  | 'error';

// Returns the result payload, or throws { code, message }.
export type CommandHandler = (
  method: string,
  params: Record<string, any>,
) => Promise<Record<string, any>>;

// A line in the session's "working traces" feed.
export interface Trace {
  id: string;
  kind: 'system' | 'agent' | 'user' | 'error';
  text: string;
  detail?: string;
  at: number;
}

const CLIENT_ID = 'metamod-ios';
const SCOPES = ['operator.read', 'operator.write'];

// Faithful port of the native GatewayClient: connects as a `node`, answers the
// gateway's Ed25519 challenge, keeps alive with pings, and dispatches node.invoke.
export class GatewayClient {
  state: ConnectionState = 'disconnected';
  lastError = '';

  private ws: WebSocket | null = null;
  private keepalive: ReturnType<typeof setInterval> | null = null;

  constructor(
    private config: GatewayConfig,
    private identity: DeviceIdentity,
    private handler: CommandHandler,
    private onState: (state: ConnectionState, error: string) => void,
    private onTrace?: (t: Trace) => void,
  ) {}

  update(config: GatewayConfig) {
    this.config = config;
  }

  private trace(kind: Trace['kind'], text: string, detail?: string) {
    this.onTrace?.({ id: uuid(), kind, text, detail, at: Date.now() });
  }

  private setState(s: ConnectionState, error = '') {
    this.state = s;
    this.lastError = error;
    this.onState(s, error);
    if (s === 'connected') this.trace('system', 'Connected to gateway as ' + this.identity.nodeID);
    if (s === 'waitingForPairing') this.trace('system', 'Waiting for pairing approval…');
    if (s === 'error') this.trace('error', error || 'Connection error');
  }

  /** Send a user chat message into the session. */
  sendChat(text: string) {
    if (!text.trim()) return;
    this.trace('user', text);
    // Node→operator chat isn't part of the core v3 command set; send it as a
    // best-effort `chat` request so gateways that support it receive it.
    this.send({ type: 'req', id: uuid(), method: 'chat', params: { text } });
  }

  connect() {
    this.disconnect();
    this.setState('connecting');
    try {
      const ws = new WebSocket(configURL(this.config));
      this.ws = ws;
      ws.onmessage = (e) => this.handleMessage(String(e.data));
      ws.onerror = () => this.setState('error', 'Connection failed');
      ws.onclose = () => {
        if (this.state !== 'error') this.setState('disconnected');
      };
    } catch (e: any) {
      this.setState('error', e?.message ?? 'Invalid gateway URL');
    }
  }

  disconnect() {
    if (this.keepalive) clearInterval(this.keepalive);
    this.keepalive = null;
    this.ws?.close();
    this.ws = null;
    if (this.state !== 'error') this.setState('disconnected');
  }

  private handleMessage(data: string) {
    const frame = decodeFrame(data);
    if (!frame) return;
    if (frame.type === 'event') {
      if (frame.event === 'connect.challenge' && typeof frame.payload.nonce === 'string') {
        this.sendConnect(frame.payload.nonce);
      }
    } else if (frame.type === 'res') {
      if (frame.error) {
        this.setState(
          frame.error.code === 'NOT_PAIRED' ? 'waitingForPairing' : 'error',
          frame.error.message,
        );
      } else if (frame.ok && this.state === 'connecting') {
        this.setState('connected');
        this.startKeepalive();
      }
    } else if (frame.type === 'req') {
      this.dispatch(frame.id, frame.method, frame.params);
    }
  }

  private sendConnect(nonce: string) {
    const signedAt = Date.now();
    const signed = signedStringV3({
      deviceID: this.identity.deviceID,
      clientID: CLIENT_ID,
      clientMode: 'node',
      role: 'node',
      scopes: SCOPES,
      signedAtMs: signedAt,
      token: this.config.token,
      nonce,
      platform: 'ios',
      deviceFamily: 'rayban',
    });
    const signature = this.identity.sign(signed);
    this.send({
      type: 'req',
      id: uuid(),
      method: 'connect',
      params: {
        minProtocol: 3,
        maxProtocol: 4,
        client: { id: CLIENT_ID, mode: 'node', name: 'Super Meta' },
        role: 'node',
        scopes: SCOPES,
        caps: ['camera'],
        commands: ['camera.snap', 'camera.list', 'device.status', 'device.info'],
        auth: { token: this.config.token },
        device: {
          id: this.identity.deviceID,
          publicKey: this.identity.publicKeyB64Url,
          nonce,
          signedAt,
          signature,
          platform: 'ios',
          deviceFamily: 'rayban',
        },
      },
    });
  }

  private async dispatch(id: string, method: string, params: Record<string, any>) {
    if (method !== 'node.invoke') {
      this.respond(id, false, undefined, { code: 'UNKNOWN_METHOD', message: method });
      return;
    }
    const command = (params.command as string) ?? '';
    const args = (params.params as Record<string, any>) ?? {};
    this.trace('agent', `Agent ran ${command}`, Object.keys(args).length ? JSON.stringify(args) : undefined);
    try {
      const payload = await this.handler(command, args);
      this.trace('system', `${command} → ok`, summarize(payload));
      this.respond(id, true, payload);
    } catch (e: any) {
      const err: GatewayError =
        e && e.code ? e : { code: 'ERROR', message: e?.message ?? String(e) };
      this.trace('error', `${command} → ${err.code}`, err.message);
      this.respond(id, false, undefined, err);
    }
  }

  private startKeepalive() {
    if (this.keepalive) clearInterval(this.keepalive);
    this.keepalive = setInterval(() => {
      if (this.state === 'connected') this.send({ type: 'req', id: uuid(), method: 'ping', params: {} });
    }, 15000);
  }

  private respond(id: string, ok: boolean, payload?: Record<string, any>, error?: GatewayError) {
    this.send({ type: 'res', id, ok, payload, error });
  }

  private send(frame: Frame) {
    if (this.ws && this.ws.readyState === 1) this.ws.send(encodeFrame(frame));
  }
}

// Short one-line summary of a command result for the trace feed (base64 blobs elided).
function summarize(payload: Record<string, any>): string {
  const parts: string[] = [];
  for (const [k, v] of Object.entries(payload)) {
    if (k === 'base64' && typeof v === 'string') parts.push(`base64(${v.length}b)`);
    else parts.push(`${k}=${typeof v === 'object' ? JSON.stringify(v) : v}`);
  }
  return parts.join(' · ');
}

function uuid(): string {
  // RFC4122-ish v4 without crypto — ids are correlation-only, not security-sensitive.
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) => {
    const r = (Math.random() * 16) | 0;
    return (c === 'x' ? r : (r & 0x3) | 0x8).toString(16);
  });
}
