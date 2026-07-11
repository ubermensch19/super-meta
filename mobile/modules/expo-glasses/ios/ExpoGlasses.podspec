Pod::Spec.new do |s|
  s.name           = 'ExpoGlasses'
  s.version        = '1.0.0'
  s.summary        = 'Super Meta glasses module — Meta Wearables DAT SDK bridge'
  s.description    = 'Expo native module wrapping the Meta Wearables DAT SDK.'
  s.author         = ''
  s.homepage       = 'https://docs.expo.dev/modules/'
  s.platforms      = {
    :ios => '16.4'
  }
  s.source         = { git: '' }
  s.static_framework = true

  s.dependency 'ExpoModulesCore'

  # Meta Wearables DAT SDK, vendored as binary xcframeworks (the SDK's SwiftPM
  # package is itself just these binaryTargets). Vendoring here links MWDATCore/
  # MWDATCamera into the module target so `import MWDATCore` resolves — the app
  # target alone can't expose them to this pod. Run ./scripts/fetch-frameworks.sh
  # if Frameworks/ is missing.
  s.vendored_frameworks = 'Frameworks/MWDATCore.xcframework', 'Frameworks/MWDATCamera.xcframework'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
  }

  s.source_files = "*.{h,m,mm,swift,hpp,cpp}"
end
