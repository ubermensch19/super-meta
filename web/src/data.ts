export type Feature = {
  title: string
  body: string
  tint: string
  icon: 'voice' | 'globe' | 'eye' | 'chat' | 'leaf' | 'node' | 'stream' | 'clock'
}

export const FEATURES: Feature[] = [
  {
    title: 'Live AI',
    body: 'Real-time voice conversation, powered by OpenAI Realtime. Talk to your glasses in Chat, Guide, or Assist mode while they see the frame in front of you.',
    tint: '#FFA62B',
    icon: 'voice',
  },
  {
    title: 'Live Translate',
    body: 'Speech-to-speech translation across 11 languages, in the moment. Hear the world in your language.',
    tint: '#39E0A0',
    icon: 'globe',
  },
  {
    title: 'Quick Vision',
    body: 'Instant recognition across seven modes — Siri-triggerable, so a glance and a phrase is all it takes.',
    tint: '#FFA62B',
    icon: 'eye',
  },
  {
    title: 'Vision Chat',
    body: 'Free-form Q&A about whatever the camera sees. Ask follow-ups; it keeps the context.',
    tint: '#39E0A0',
    icon: 'chat',
  },
  {
    title: 'LeanEat',
    body: 'Point at a plate for a nutrition and calorie breakdown before the first bite.',
    tint: '#FF4D8D',
    icon: 'leaf',
  },
  {
    title: 'Agent Link',
    body: 'Attach the glasses as a live node to an OpenClaw or Hermes agent gateway — a real-world sensor for your agents.',
    tint: '#FFA62B',
    icon: 'node',
  },
  {
    title: 'Live Stream',
    body: 'Broadcast the glasses camera over RTMP to YouTube, Twitch, or any custom endpoint.',
    tint: '#FF4D8D',
    icon: 'stream',
  },
  {
    title: 'Records',
    body: 'Every vision result, saved on-device with SwiftData. Scroll back through what you have seen.',
    tint: '#9A9BA6',
    icon: 'clock',
  },
]

export type ShowcaseScene = {
  tag: string
  heard: string
  answered: string
  tint: string
  latency: string
}

export const SCENES: ShowcaseScene[] = [
  {
    tag: 'QUICK VISION',
    heard: 'What am I looking at, and is it safe to eat?',
    answered: 'A ripe Hachiya persimmon. Fully soft — safe to eat now.',
    tint: '#FFA62B',
    latency: '0.24s',
  },
  {
    tag: 'LIVE TRANSLATE',
    heard: '「この電車は渋谷に行きますか？」',
    answered: 'They asked: “Does this train go to Shibuya?” — Yes, three stops.',
    tint: '#39E0A0',
    latency: '0.31s',
  },
  {
    tag: 'LEANEAT',
    heard: 'How many calories is this plate?',
    answered: 'Grain bowl ≈ 620 kcal · 34g protein · 71g carbs · 22g fat.',
    tint: '#FF4D8D',
    latency: '0.28s',
  },
  {
    tag: 'AGENT LINK',
    heard: 'agent: camera.snap → describe the whiteboard',
    answered: 'Captured. Sprint board: 4 in progress, 2 blocked on review.',
    tint: '#3B7BF6',
    latency: '0.19s',
  },
]

export type IconName = Feature['icon']
