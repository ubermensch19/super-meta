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

More modules (`GlassesKit`, `AIProviders`, `RealtimeVoice`, `AgentGateway`, `Persistence`, `FeatureKit`) land in later phases.

## Build

```sh
xcodegen generate          # (re)generate MetaMod.xcodeproj from project.yml
open MetaMod.xcodeproj      # then set your signing team + Meta credentials
```

Meta credentials (`META_APP_ID`, `CLIENT_TOKEN`) and `DEVELOPMENT_TEAM` are build settings — fill them in `project.yml` or override in Xcode. The `.xcodeproj` is git-ignored; regenerate it with `xcodegen generate`.

## Status

Phase 0 (scaffold) complete — design system + app shell build and run. See the build plan for the phased roadmap toward full feature parity.
