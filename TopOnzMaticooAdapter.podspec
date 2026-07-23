#
# Be sure to run `pod lib lint TopOnzMaticooAdapter.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'TopOnzMaticooAdapter'
  s.version          = '2.2.0.1'
  s.summary          = 'zMaticoo iOS SDK AnyThinkiOS (TopOn) Adapter.'

  s.description      = <<-DESC
This is zMaticoo iOS SDK AnyThinkiOS Adapter.
Supports Latest TopOn and Legacy TopOn (AnyThinkiOS <= 6.4.92) via mutually exclusive subspecs.
                       DESC

  s.homepage         = 'https://www.zmaticoo.com'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { '15967863@qq.com' => 'lovely-kitty@live.cn' }
  s.source           = { :git => 'https://github.com/zMaticoo/zMaticooiOSTopOnAdapter.git', :tag => s.version.to_s }

  s.ios.deployment_target = '12.0'
  s.static_framework = true

  # Latest 与 Legacy 互斥：类名相同（TopOn 按类名注册），同一 target 只能选其一。
  #   pod 'TopOnzMaticooAdapter'                              → Latest（默认）
  #   pod 'TopOnzMaticooAdapter', :subspecs => ['Legacy']     → AnyThinkiOS ≤ 6.4.92
  s.default_subspec = 'Latest'

  # 当前 TopOn / AnyThinkiOS（> 6.4.92）适配器
  s.subspec 'Latest' do |ss|
    ss.source_files = 'Classes/**/*.{h,m}'
    ss.dependency 'zMaticoo'
    ss.dependency 'AnyThinkiOS'
  end

  # TopOn / AnyThinkiOS 6.4.92 及以前版本兼容适配器
  s.subspec 'Legacy' do |ss|
    ss.source_files = 'ClassesLegacy/**/*.{h,m}'
    ss.dependency 'zMaticoo'
    ss.dependency 'AnyThinkiOS', '<= 6.4.92'
  end
end
