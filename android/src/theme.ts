// Super Meta design tokens — a dark, cinematic heads-up-display aesthetic.
// Ported from the native app's DesignSystem/Theme.swift so both platforms stay in sync.

export const Palette = {
  canvas: '#0B0B0F', // base canvas — near-black
  surface: '#16161D', // elevated glass surface
  surfaceHigh: '#20212B', // higher elevation / pressed surface
  border: '#2E2F3A', // hairline borders on glass
  accent: '#FFA62B', // primary signal accent — warm amber
  live: '#FF4D8D', // live / recording state — magenta
  positive: '#39E0A0', // positive / connected — teal
  textPrimary: '#F4F4F6', // near-white
  textSecondary: '#9A9BA6', // light gray
  textMuted: '#61626C', // darker gray
} as const;

export const Spacing = {
  xs: 4,
  sm: 8,
  md: 16,
  lg: 24,
  xl: 32,
} as const;

export const Radius = {
  sm: 10,
  md: 16,
  lg: 24,
  pill: 999,
} as const;

export const Font = {
  display: 34,
  title: 22,
  body: 17,
  readout: 13, // mono HUD readouts
} as const;
