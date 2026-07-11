import { Palette } from '../theme';
import {
  useGlassesStatus,
  startRegistration,
  isNativeAvailable,
  type GlassesStatus,
  type Registration,
} from '../../modules/expo-glasses';

// Thin app-facing wrapper over the expo-glasses native module. In Expo Go (or on
// web) the module is absent and this reports the "no glasses · using photos"
// fallback; in a dev/production build it reflects the live DAT SDK connection.
export type { Registration, GlassesStatus };

export function useGlasses(): GlassesStatus {
  return useGlassesStatus();
}

export { startRegistration, isNativeAvailable };

export function connectionText(g: GlassesStatus): string {
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

export function dotColor(g: GlassesStatus): string {
  if (g.hasActiveDevice) return Palette.positive;
  if (g.registration === 'registered') return Palette.accent;
  return Palette.textMuted;
}
