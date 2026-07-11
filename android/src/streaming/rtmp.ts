import { useEffect, useState } from 'react';

// RTMP live-streaming interface for the glasses camera. The actual encoder is a
// native module (HaishinKit on iOS / RootEncoder on Android) fed by the glasses
// frame stream — mirroring the native app's RTMPService. It loads only in a dev
// build; in Expo Go this reports unavailable so the config screen still works.
export type RtmpState = 'idle' | 'connecting' | 'streaming' | 'error';

export interface RtmpStatus {
  state: RtmpState;
  framesSent: number;
  error?: string;
}

type NativeRtmp = {
  start(url: string, streamKey: string): Promise<void>;
  stop(): Promise<void>;
  getStatus(): RtmpStatus;
  addListener(event: 'onStatus', cb: (s: RtmpStatus) => void): { remove: () => void };
};

let native: NativeRtmp | null = null;
try {
  // eslint-disable-next-line @typescript-eslint/no-var-requires
  native = require('expo').requireNativeModule('ExpoRtmp');
} catch {
  native = null;
}

export const isRtmpAvailable = native != null;

export const RTMP_PRESETS: { name: string; url: string }[] = [
  { name: 'YouTube', url: 'rtmp://a.rtmp.youtube.com/live2' },
  { name: 'Twitch', url: 'rtmp://live.twitch.tv/app' },
  { name: 'Custom', url: '' },
];

export async function startStream(url: string, streamKey: string): Promise<void> {
  await native?.start(url, streamKey);
}

export async function stopStream(): Promise<void> {
  await native?.stop();
}

export function useRtmpStatus(): RtmpStatus {
  const [status, setStatus] = useState<RtmpStatus>(() => native?.getStatus() ?? { state: 'idle', framesSent: 0 });
  useEffect(() => {
    if (!native) return;
    const sub = native.addListener('onStatus', setStatus);
    return () => sub.remove();
  }, []);
  return status;
}
