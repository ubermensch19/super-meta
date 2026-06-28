# Meta-Mod

A smart-glasses AI assistant for Ray-Ban Meta glasses, built on Meta's Wearables DAT SDK. Multimodal vision and real-time voice, powered by your choice of OpenAI, Anthropic Claude, or OpenRouter, with optional connection to OpenClaw / Hermes agent gateways.

> "Meta" is a trademark of Meta Platforms — `Meta-Mod` is a working name for development only and must be renamed before any public distribution.

## Requirements

- Xcode 16+ (built with Xcode 26.6, Swift 6)
- iOS 17+ device
- [XcodeGen](https://github.com/yonyz/XcodeGen) (`brew install xcodegen`) — the project is generated from `project.yml`
- Ray-Ban Meta glasses (firmware v20+, DAT SDK Preview Mode enabled) for on-device features

## Project layout

```
project.yml                 # XcodeGen spec — source of truth for the Xcode project
App/                        # app target (entry point, root UI)
Packages/
  DesignSystem/             # HUD design tokens + components
```

Local packages: `DesignSystem` (HUD theme), `AIProviders` (Gemini/OpenAI/Claude/OpenRouter), `GlassesKit` (DAT SDK wrapper), `RealtimeVoice` (OpenAI Realtime + audio engine), `AgentGateway` (OpenClaw/Hermes node client). The app target hosts the features, settings, persistence, and Siri intents.

## Features

- **Live AI** — real-time voice conversation (OpenAI Realtime GA) with optional glasses-frame context; Chat/Guide/Assist modes
- **Live Translate** — speech-to-speech translation across 11 languages
- **Quick Vision** — image recognition with 7 modes; Siri-triggerable
- **Vision Chat** — free-form Q&A about an image
- **LeanEat** — food/nutrition analysis
- **Agent Link** — connect the glasses as a node to OpenClaw or Hermes gateways
- **Live Stream** — broadcast the glasses camera over RTMP (YouTube/Twitch/custom)
- **Records** — SwiftData history of vision results

Provider keys are entered in Settings (stored in the Keychain). Vision features use your selected provider; realtime voice uses OpenAI. When no glasses are connected (e.g. Simulator), vision features fall back to a photo picker.

## Build

```sh
xcodegen generate          # (re)generate MetaMod.xcodeproj from project.yml
open MetaMod.xcodeproj      # then set your signing team + Meta credentials
```

Meta credentials (`META_APP_ID`, `CLIENT_TOKEN`) and `DEVELOPMENT_TEAM` are build settings — fill them in `project.yml` or override in Xcode. The `.xcodeproj` is git-ignored; regenerate it with `xcodegen generate`.

## Status

Full feature set implemented and building. Validation: app builds + runs (Simulator); live provider/realtime/gateway tests green (`AIProviders` 7/7, `AgentGateway` 6/6, `RealtimeVoice` 1/1). Glasses camera/photo/mic, RTMP, and a live OpenClaw/Hermes gateway require on-device verification with Meta credentials.

Run tests with keys in the environment:

```sh
GEMINI_API_KEY=... OPENAI_API_KEY=... (cd Packages/AIProviders && swift test)
OPENAI_API_KEY=... (cd Packages/RealtimeVoice && swift test)
```
