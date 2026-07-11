import { Palette } from '../theme';

// Connection state mirrors the native GlassesService. Until the Meta Wearables
// DAT SDK is bridged as a native module (needs an Expo dev build, not Expo Go),
// this reports the "no glasses · using photos" fallback path the app already has.

export type Registration = 'notLinked' | 'registering' | 'registered';

export interface GlassesState {
  isAvailable: boolean;
  registration: Registration;
  hasActiveDevice: boolean;
}

export function useGlasses(): GlassesState {
  // Static stub for now; becomes a real hook over the native module later.
  return { isAvailable: false, registration: 'notLinked', hasActiveDevice: false };
}

export function connectionText(g: GlassesState): string {
  if (!g.isAvailable) return 'No glasses · using photos';
  switch (g.registration) {
    case 'registered':
      return g.hasActiveDevice ? 'Glasses connected' : 'Linked · turn on glasses';
    case 'registering':
      return 'Connecting…';
    default:
      return 'Glasses not linked';
  }
}

export function dotColor(g: GlassesState): string {
  if (g.hasActiveDevice) return Palette.positive;
  if (g.registration === 'registered') return Palette.accent;
  return Palette.textMuted;
}
