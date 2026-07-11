import { NativeModule, requireNativeModule } from 'expo';

import { ExpoGlassesEvents, GlassesStatus } from './ExpoGlasses.types';

declare class ExpoGlassesModule extends NativeModule<ExpoGlassesEvents> {
  /** Current snapshot of connection/stream state. */
  getStatus(): GlassesStatus;
  /** Register with the Meta AI app. No-op if already registered. */
  startRegistration(): Promise<void>;
  startUnregistration(): Promise<void>;
  /** Finish the Meta AI OAuth handshake from a deep-link callback URL. */
  handleUrl(url: string): void;
  /** Start/stop the camera stream. Requests camera permission as needed. */
  startStreaming(): Promise<void>;
  stopStreaming(): Promise<void>;
  /** Capture a single JPEG; resolves to a base64 string. */
  capturePhoto(): Promise<string>;
}

// Returns the native module. Only present in a dev build / production build —
// not in Expo Go (custom native code can't load there). Callers should guard.
export default requireNativeModule<ExpoGlassesModule>('ExpoGlasses');
