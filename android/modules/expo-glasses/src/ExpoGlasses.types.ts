// Public types for the Super Meta glasses native module. These mirror the
// native GlassesService (iOS/Swift) and WearablesViewModel (Android/Kotlin)
// wrappers over Meta's Wearables DAT SDK, so the JS API is identical on both.

export type Registration = 'unavailable' | 'notRegistered' | 'registering' | 'registered';

export type StreamState = 'stopped' | 'waiting' | 'streaming' | 'error';

export interface GlassesStatus {
  /** False when the SDK can't be configured (e.g. simulator / no Meta AI app). */
  isAvailable: boolean;
  registration: Registration;
  /** A glasses device is currently selected/active. */
  hasActiveDevice: boolean;
  streamState: StreamState;
  lastError?: string;
}

// Event payloads emitted to JS. `onStatus` fires on any state transition;
// `onFrame` delivers a base64 JPEG of the latest camera frame.
export type ExpoGlassesEvents = {
  onStatus: (status: GlassesStatus) => void;
  onFrame: (frame: { base64: string; width: number; height: number }) => void;
};
