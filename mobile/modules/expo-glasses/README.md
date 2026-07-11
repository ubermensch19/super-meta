# expo-glasses

Native module wrapping Meta's **Wearables DAT SDK** for the Super Meta RN app, with
one JS API across iOS and Android. Ported from the native app's `GlassesService`
(Swift) and turbometa's `WearablesViewModel` (Kotlin).

## JS API

```ts
import {
  useGlassesStatus, getStatus, startRegistration, startStreaming,
  stopStreaming, capturePhoto, isNativeAvailable,
} from '../../modules/expo-glasses';
```

`useGlassesStatus()` returns live `{ isAvailable, registration, hasActiveDevice, streamState }`.
In **Expo Go** (or web) the native module isn't present, so everything reports
`unavailable` and the app runs in its "using photos" fallback — no crash.

## Requirements to actually run the glasses

The module only loads in a **dev/production build**, not Expo Go:

```sh
npx expo prebuild            # applies plugins/withGlasses.js
```

**iOS** — no secrets. The SDK is the public SwiftPM package
`github.com/facebook/meta-wearables-dat-ios@0.5.0` and we use Developer Mode
(`MetaAppID = 0`). The plugin adds the package to the app target.
```sh
cd ios && pod install && cd ..
npx expo run:ios --device      # a real iPhone + real Ray-Ban glasses is required to see it connect
```
> Note: the SwiftPM products are added to the **app** target. If `canImport(MWDATCore)`
> resolves false inside the module during the first build (glasses stay "unavailable"),
> add `MWDATCore`/`MWDATCamera` to the **ExpoGlasses** target's dependencies in Xcode —
> this is the one linkage step that can't be pre-validated without a device build.

**Android** — needs a GitHub token with **`read:packages`** for the DAT Maven artifact:
```sh
gh auth refresh -h github.com -s read:packages   # or create a PAT
export GITHUB_TOKEN=$(gh auth token)
export GITHUB_ACTOR=<your-github-username>
npx expo run:android
```

## Verified vs. pending

- ✅ JS API + `useGlassesStatus` hook (type-checked; Expo Go fallback works)
- ✅ `plugins/withGlasses.js` injects Info.plist / pbxproj SwiftPM / Android manifest / Maven repo (confirmed via `expo prebuild`)
- ⏳ Native compile + runtime — needs a dev build, the Android `read:packages` token, and a physical iPhone + Ray-Ban glasses (the SDK is inert on simulators/emulators).
