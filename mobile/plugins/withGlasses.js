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
  withXcodeProject,
  AndroidConfig,
} = require('@expo/config-plugins');

const SCHEME = 'supermeta';
const SPM_URL = 'https://github.com/facebook/meta-wearables-dat-ios';
const SPM_VERSION = '0.5.0';

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

// Best-effort: add the MWDAT SwiftPM package to the app target. pbxproj SPM
// manipulation is finicky, so on any failure we log the exact manual step
// instead of producing a broken project.
function withIosSwiftPackage(config) {
  return withXcodeProject(config, (c) => {
    try {
      const proj = c.modResults;
      const pkgRef = proj.generateUuid();
      const products = ['MWDATCore', 'MWDATCamera'];

      proj.hash.project.objects.XCRemoteSwiftPackageReference ||= {};
      proj.hash.project.objects.XCRemoteSwiftPackageReference[pkgRef] = {
        isa: 'XCRemoteSwiftPackageReference',
        repositoryURL: `"${SPM_URL}"`,
        requirement: { kind: 'exactVersion', version: SPM_VERSION },
      };

      const target = Object.values(proj.hash.project.objects.PBXNativeTarget).find(
        (t) => t && typeof t === 'object' && t.productType?.includes('application'),
      );
      target.packageProductDependencies ||= [];
      for (const name of products) {
        const depId = proj.generateUuid();
        proj.hash.project.objects.XCSwiftPackageProductDependency ||= {};
        proj.hash.project.objects.XCSwiftPackageProductDependency[depId] = {
          isa: 'XCSwiftPackageProductDependency',
          package: pkgRef,
          productName: name,
        };
        target.packageProductDependencies.push({ value: depId, comment: name });
      }
      const rootId = proj.hash.project.rootObject;
      const root = proj.hash.project.objects.PBXProject[rootId];
      root.packageReferences ||= [];
      root.packageReferences.push({ value: pkgRef, comment: 'XCRemoteSwiftPackageReference' });
    } catch (e) {
      console.warn(
        `[withGlasses] Could not auto-add the MWDAT SwiftPM package (${e.message}). ` +
          `Add it manually in Xcode: File → Add Package Dependencies → ${SPM_URL} @ ${SPM_VERSION} → MWDATCore + MWDATCamera.`,
      );
    }
    return c;
  });
}

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
  config = withIosSwiftPackage(config);
  config = withAndroidGlassesManifest(config);
  config = withAndroidDatRepo(config);
  return config;
};
