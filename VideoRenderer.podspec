Pod::Spec.new do |s|
  s.name             = 'VideoRenderer'
  s.version          = 'new_version'
  s.summary          = 'Default video renderers for OneMobileSDK.'
  s.homepage         = 'https://github.com/aol-public/OneMobileSDK-videorenderer-ios.git'
  s.license          = { type: 'MIT', file: 'LICENSE' }
  s.author           = { 'Andrey Moskvin' => 'andrey.moskvin@teamaol.com' }
  s.source           = { http: 'framework_zip_url' }

  s.ios.deployment_target = '8.0'
  s.tvos.deployment_target = '9.0'

  s.ios.vendored_frameworks = 'Carthage/Build/iOS/VideoRenderer.framework'
  s.tvos.vendored_frameworks = 'Carthage/Build/tvOS/VideoRenderer.framework'
end
