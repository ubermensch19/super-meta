import type { IconName } from './components/Icon';
import { Palette } from './theme';

// Route table for the native-stack. Mirrors the NavigationLinks in the
// SwiftUI HomeView so feature parity is one-to-one across platforms.
export type RootStackParamList = {
  Home: undefined;
  LiveAI: undefined;
  QuickVision: undefined;
  VisionChat: undefined;
  LeanEat: undefined;
  LiveTranslate: undefined;
  AgentLink: undefined;
  LiveStream: undefined;
  Records: undefined;
  Settings: undefined;
};

export type RouteName = keyof RootStackParamList;

export interface Feature {
  route: RouteName;
  title: string;
  subtitle: string;
  icon: IconName;
  tint: string;
  /** What this screen does — shown on the placeholder until it's built out. */
  blurb: string;
}

export const SEE: Feature[] = [
  {
    route: 'QuickVision',
    title: 'Quick Vision',
    subtitle: 'Recognize',
    icon: 'eye',
    tint: Palette.accent,
    blurb: 'Point the glasses and recognize what you are looking at across seven modes.',
  },
  {
    route: 'VisionChat',
    title: 'Vision Chat',
    subtitle: 'Ask anything',
    icon: 'chat',
    tint: Palette.positive,
    blurb: 'Free-form Q&A about whatever the camera sees.',
  },
  {
    route: 'LeanEat',
    title: 'LeanEat',
    subtitle: 'Nutrition',
    icon: 'leaf',
    tint: Palette.live,
    blurb: 'Point at food to get a nutrition and calorie breakdown.',
  },
];

export const CONNECT: Feature[] = [
  {
    route: 'AgentLink',
    title: 'Agent Link',
    subtitle: 'OpenClaw · Hermes',
    icon: 'antenna',
    tint: Palette.accent,
    blurb: 'Attach the glasses as a live node to an OpenClaw or Hermes agent gateway.',
  },
  {
    route: 'LiveStream',
    title: 'Live Stream',
    subtitle: 'Broadcast RTMP',
    icon: 'broadcast',
    tint: Palette.live,
    blurb: 'Broadcast the glasses camera over RTMP to YouTube, Twitch, or a custom URL.',
  },
];
