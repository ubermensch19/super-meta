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

**iOS** — no secrets. The SDK's SwiftPM package is just binary xcframeworks, which
this module **vendors** (`ios/Frameworks/*.xcframework`, referenced by the podspec)
so `MWDATCore` links into the module target. We use Developer Mode (`MetaAppID = 0`).
The frameworks are gitignored (~74 MB) — run `scripts/fetch-frameworks.sh` after clone.
```sh
scripts/fetch-frameworks.sh            # if modules/expo-glasses/ios/Frameworks is empty
npx expo run:ios --device              # a real iPhone + Ray-Ban glasses to see it connect
```

**Android** — needs a GitHub token with **`read:packages`** for the DAT Maven artifact:
```sh
gh auth refresh -h github.com -s read:packages   # or create a PAT
export GITHUB_TOKEN=$(gh auth token)
export GITHUB_ACTOR=<your-github-username>
npx expo run:android
```

## Verified vs. pending

- ✅ JS API + `useGlassesStatus` hook (type-checked; Expo Go fallback works)
- ✅ `plugins/withGlasses.js` injects Info.plist / Android manifest / Maven repo (confirmed via `expo prebuild`)
- ✅ **iOS dev build compiles and runs** — the module links MWDATCore/MWDATCamera, `Wearables.configure()` succeeds, and the app reports "Glasses not linked" (i.e. the SDK is live; a simulator just has no device to link).
- ⏳ **Android** compile — needs the `read:packages` token (the Kotlin is ported but unbuilt).
- ⏳ **End-to-end glasses** — needs a physical iPhone + Ray-Ban glasses paired via the Meta AI app (the SDK can't connect on a simulator/emulator).
