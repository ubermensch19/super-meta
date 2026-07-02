import React from 'react';
import { Ionicons, Feather, MaterialCommunityIcons } from '@expo/vector-icons';

// Maps the app's semantic icon names (originally SF Symbols) onto vector-icon
// sets that ship with Expo, so the RN UI reads the same as the native app.
export type IconName =
  | 'settings'
  | 'mic'
  | 'arrow-up-right'
  | 'chevron'
  | 'eye'
  | 'chat'
  | 'leaf'
  | 'globe'
  | 'antenna'
  | 'broadcast'
  | 'clock';

export function Icon({
  name,
  size = 20,
  color,
}: {
  name: IconName;
  size?: number;
  color: string;
}) {
  switch (name) {
    case 'settings':
      return <Ionicons name="settings-outline" size={size} color={color} />;
    case 'mic':
      return <Ionicons name="mic" size={size} color={color} />;
    case 'arrow-up-right':
      return <Feather name="arrow-up-right" size={size} color={color} />;
    case 'chevron':
      return <Ionicons name="chevron-forward" size={size} color={color} />;
    case 'eye':
      return <Ionicons name="eye-outline" size={size} color={color} />;
    case 'chat':
      return <Ionicons name="chatbubbles-outline" size={size} color={color} />;
    case 'leaf':
      return <Ionicons name="leaf-outline" size={size} color={color} />;
    case 'globe':
      return <Ionicons name="globe-outline" size={size} color={color} />;
    case 'antenna':
      return <MaterialCommunityIcons name="access-point" size={size} color={color} />;
    case 'broadcast':
      return <MaterialCommunityIcons name="broadcast" size={size} color={color} />;
    case 'clock':
      return <Ionicons name="time-outline" size={size} color={color} />;
  }
}
