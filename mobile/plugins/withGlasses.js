// Expo config plugin for the Super Meta glasses module. Injects the Meta
// Wearables DAT SDK wiring into the prebuilt iOS/Android projects so a dev build
// picks it up. Runs during `npx expo prebuild`.
//
// iOS: needs nothing secret — the SDK is a public SwiftPM package and we use
//      Developer Mode (MetaAppID = 0).
// Android: the DAT SDK is a GitHub Packages Maven artifact; set GITHUB_TOKEN
//      (a PAT with read:packages) in the environment before prebuild/build.

const {
  withInfoPlist,
  withAndroidManifest,
  withProjectBuildGradle,
  AndroidConfig,
} = require('@expo/config-plugins');

const SCHEME = 'supermeta';

// ---- iOS ----

function withIosInfoPlist(config) {
  return withInfoPlist(config, (c) => {
    const p = c.modResults;
    p.MWDAT = { AppLinkURLScheme: `${SCHEME}://`, MetaAppID: '0' }; // Developer Mode
    p.NSBluetoothAlwaysUsageDescription =
      p.NSBluetoothAlwaysUsageDescription || 'Super Meta connects to your glasses over Bluetooth.';
    p.UIBackgroundModes = Array.from(
      new Set([...(p.UIBackgroundModes || []), 'bluetooth-central', 'external-accessory']),
    );
    return c;
  });
}

// Note: the iOS MWDAT SDK is linked via the module's podspec (vendored xcframeworks
// in modules/expo-glasses/ios/Frameworks), not here — that puts the SDK in the
// module target so `import MWDATCore` resolves.

// ---- Android ----

function withAndroidGlassesManifest(config) {
  config = AndroidConfig.Permissions.withPermissions(config, [
    'android.permission.BLUETOOTH_CONNECT',
    'android.permission.BLUETOOTH_SCAN',
  ]);
  return withAndroidManifest(config, (c) => {
    const app = AndroidConfig.Manifest.getMainApplicationOrThrow(c.modResults);
    app['meta-data'] = app['meta-data'] || [];
    if (!app['meta-data'].some((m) => m.$['android:name'] === 'com.meta.wearable.mwdat.APPLICATION_ID')) {
      app['meta-data'].push({
        $: { 'android:name': 'com.meta.wearable.mwdat.APPLICATION_ID', 'android:value': '0' },
      });
    }
    return c;
  });
}

// Inject the DAT Maven repo (with GITHUB_TOKEN credentials) into allprojects.
function withAndroidDatRepo(config) {
  return withProjectBuildGradle(config, (c) => {
    if (c.modResults.contents.includes('meta-wearables-dat-android')) return c;
    const repo = `
        maven {
            url = uri("https://maven.pkg.github.com/facebook/meta-wearables-dat-android")
            credentials {
                username = System.getenv("GITHUB_ACTOR") ?: "x-access-token"
                password = System.getenv("GITHUB_TOKEN") ?: ""
            }
        }`;
    c.modResults.contents = c.modResults.contents.replace(
      /allprojects\s*\{\s*repositories\s*\{/,
      (m) => `${m}${repo}`,
    );
    return c;
  });
}

module.exports = function withGlasses(config) {
  config = withIosInfoPlist(config);
  config = withAndroidGlassesManifest(config);
  config = withAndroidDatRepo(config);
  return config;
};
