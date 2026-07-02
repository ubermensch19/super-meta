import { useEffect, useState } from 'react';

import { GlassesStatus } from './src/ExpoGlasses.types';

export * from './src/ExpoGlasses.types';

const UNAVAILABLE: GlassesStatus = {
  isAvailable: false,
  registration: 'unavailable',
  hasActiveDevice: false,
  streamState: 'stopped',
};

// Load the native module lazily. In Expo Go (no custom native code) or on web,
// requireNativeModule throws — we swallow it and report the unavailable state so
// the app still runs. The real module is present only in a dev/production build.
let native: typeof import('./src/ExpoGlassesModule').default | null = null;
try {
  native = require('./src/ExpoGlassesModule').default;
} catch {
  native = null;
}

export const isNativeAvailable = native != null;

export function getStatus(): GlassesStatus {
  return native ? native.getStatus() : UNAVAILABLE;
}

export async function startRegistration(): Promise<void> {
  await native?.startRegistration();
}

export async function startUnregistration(): Promise<void> {
  await native?.startUnregistration();
}

export function handleUrl(url: string): void {
  native?.handleUrl(url);
}

export async function startStreaming(): Promise<void> {
  await native?.startStreaming();
}

export async function stopStreaming(): Promise<void> {
  await native?.stopStreaming();
}

export async function capturePhoto(): Promise<string | null> {
  return native ? native.capturePhoto() : null;
}

/**
 * React hook returning live glasses status. Subscribes to native `onStatus`
 * events when the module is present; otherwise returns the unavailable state.
 */
export function useGlassesStatus(): GlassesStatus {
  const [status, setStatus] = useState<GlassesStatus>(() => getStatus());

  useEffect(() => {
    if (!native) return;
    const sub = native.addListener('onStatus', setStatus);
    setStatus(native.getStatus());
    return () => sub.remove();
  }, []);

  return status;
}
