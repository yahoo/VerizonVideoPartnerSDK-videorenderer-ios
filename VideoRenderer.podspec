Pod::Spec.new do |s|
  s.name             = 'VideoRenderer'
  s.version          = '1.28'
  s.summary          = 'Default video renderers for VerizonVideoPartnerSDK.'
  s.license          = { type: 'MIT', file: 'LICENSE' }
  s.swift_version    = '4.2'
  s.homepage         = 'https://github.com/VerizonAdPlatforms/VerizonVideoPartnerSDK-videorenderer-ios.git'
  s.author           = {
    'Andrey Moskvin' => 'andrey.moskvin@oath.com',
    'Roman Tysiachnik' => 'roman.tysiachnik@oath.com',
    'Vladyslav Anokhin' => 'vladyslav.anokhin@oath.com'
  }
  s.source = { :git => 'https://github.com/VerizonAdPlatforms/VerizonVideoPartnerSDK-videorenderer-ios.git',
               :tag => s.version.to_s }
  s.source_files     = 'VideoRenderer/**/*.swift'
  s.exclude_files    = 'VideoRenderer/**/*Test*'

  s.ios.deployment_target = '9.0'
  s.tvos.deployment_target = '9.0'
end
