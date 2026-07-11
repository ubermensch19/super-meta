import AsyncStorage from '@react-native-async-storage/async-storage';
import { useCallback, useEffect, useRef, useState } from 'react';

import { capturePhoto, getStatus as glassesStatus } from '../../modules/expo-glasses';
import { loadIdentity } from './identity';
import { CommandHandler, ConnectionState, DEFAULT_CONFIG, GatewayClient, GatewayConfig } from './GatewayClient';

const KEYS = { host: 'gateway_host', port: 'gateway_port', tls: 'gateway_tls', token: 'gateway_token' };

async function loadConfig(): Promise<GatewayConfig> {
  const [host, port, tls, token] = await Promise.all([
    AsyncStorage.getItem(KEYS.host),
    AsyncStorage.getItem(KEYS.port),
    AsyncStorage.getItem(KEYS.tls),
    AsyncStorage.getItem(KEYS.token),
  ]);
  return {
    host: host ?? DEFAULT_CONFIG.host,
    port: port ? parseInt(port, 10) : DEFAULT_CONFIG.port,
    useTLS: tls === 'true',
    token: token ?? '',
  };
}

async function saveConfig(c: GatewayConfig) {
  await Promise.all([
    AsyncStorage.setItem(KEYS.host, c.host),
    AsyncStorage.setItem(KEYS.port, String(c.port)),
    AsyncStorage.setItem(KEYS.tls, String(c.useTLS)),
    AsyncStorage.setItem(KEYS.token, c.token),
  ]);
}

// Node command handler — mirrors GatewayService.handle (camera.snap / camera.list
// / device.status / device.info). camera.snap pulls a frame from the glasses module.
function makeHandler(nodeID: string): CommandHandler {
  return async (method, params) => {
    switch (method) {
      case 'camera.snap': {
        const base64 = await capturePhoto();
        if (!base64) throw { code: 'NO_FRAME', message: 'No camera frame available' };
        return { format: 'jpg', base64, bytes: Math.floor((base64.length * 3) / 4) };
      }
      case 'camera.list':
        return { cameras: [{ id: 'rayban-main', name: 'Ray-Ban Meta', facing: 'front' }] };
      case 'device.status': {
        const s = glassesStatus();
        return { available: s.isAvailable, connected: s.hasActiveDevice, streaming: s.streamState === 'streaming' };
      }
      case 'device.info':
        return { device: 'rayban-meta', app: 'Super Meta', platform: 'ios', node: nodeID };
      default:
        throw { code: 'UNKNOWN_COMMAND', message: method };
    }
  };
}

export interface GatewayHook {
  state: ConnectionState;
  error: string;
  nodeID: string;
  config: GatewayConfig;
  ready: boolean;
  setConfig: (c: GatewayConfig) => void;
  connect: () => void;
  disconnect: () => void;
}

export function useGateway(): GatewayHook {
  const [state, setState] = useState<ConnectionState>('disconnected');
  const [error, setError] = useState('');
  const [nodeID, setNodeID] = useState('rayban-…');
  const [config, setConfigState] = useState<GatewayConfig>(DEFAULT_CONFIG);
  const [ready, setReady] = useState(false);
  const client = useRef<GatewayClient | null>(null);

  useEffect(() => {
    let alive = true;
    (async () => {
      const [identity, cfg] = await Promise.all([loadIdentity(), loadConfig()]);
      if (!alive) return;
      setNodeID(identity.nodeID);
      setConfigState(cfg);
      client.current = new GatewayClient(cfg, identity, makeHandler(identity.nodeID), (s, e) => {
        setState(s);
        setError(e);
      });
      setReady(true);
    })();
    return () => {
      alive = false;
      client.current?.disconnect();
    };
  }, []);

  const setConfig = useCallback((c: GatewayConfig) => {
    setConfigState(c);
    client.current?.update(c);
    void saveConfig(c);
  }, []);

  const connect = useCallback(() => client.current?.connect(), []);
  const disconnect = useCallback(() => client.current?.disconnect(), []);

  return { state, error, nodeID, config, ready, setConfig, connect, disconnect };
}
