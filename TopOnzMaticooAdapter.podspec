#
# Be sure to run `pod lib lint TopOnzMaticooAdapter.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'TopOnzMaticooAdapter'
  s.version          = '2.3.0'
  s.summary          = 'zMaticoo iOS SDK TopOn (AnyThinkiOS / TPNiOS) Adapter.'

  s.description      = <<-DESC
This is zMaticoo iOS SDK TopOn Adapter.
Supports AnyThinkiOS and TPNiOS via mutually exclusive subspecs.
Latest / Legacy code paths are also mutually exclusive (same adapter class names).
                       DESC

  s.homepage         = 'https://www.zmaticoo.com'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { '15967863@qq.com' => 'lovely-kitty@live.cn' }
  s.source           = { :git => 'https://github.com/zMaticoo/zMaticooiOSTopOnAdapter.git', :tag => s.version.to_s }

  s.ios.deployment_target = '12.0'
  s.static_framework = true

  # 互斥约束：
  # 1) Latest* 与 Legacy* 类名相同，同一 target 只能选其一
  # 2) *AnyThink 与 *TPN 会带入同名 xcframework，同一 target 只能选其一
  #
  #   pod 'TopOnzMaticooAdapter'                                   → Latest（AnyThinkiOS，默认）
  #   pod 'TopOnzMaticooAdapter', :subspecs => ['Legacy']           → Legacy + AnyThinkiOS ≤ 6.4.92
  #   pod 'TopOnzMaticooAdapter', :subspecs => ['LatestTPN']        → Latest + TPNiOS
  #   pod 'TopOnzMaticooAdapter', :subspecs => ['LegacyTPN']        → Legacy + TPNiOS ≤ 6.4.92
  s.default_subspec = 'Latest'

  # 当前 TopOn / AnyThinkiOS（> 6.4.92）适配器
  s.subspec 'Latest' do |ss|
    ss.source_files = 'Classes/**/*.{h,m}'
    ss.dependency 'zMaticoo', '>= 2.3.0'
    ss.dependency 'AnyThinkiOS'
  end

  # TopOn / AnyThinkiOS 6.4.92 及以前版本兼容适配器
  s.subspec 'Legacy' do |ss|
    ss.source_files = 'ClassesLegacy/**/*.{h,m}'
    ss.dependency 'zMaticoo', '>= 2.3.0'
    ss.dependency 'AnyThinkiOS', '<= 6.4.92'
  end

  # 当前 TopOn / TPNiOS（与 Latest 同代码，依赖改为 TPNiOS，避免与宿主 TPNiOS 撞 framework）
  s.subspec 'LatestTPN' do |ss|
    ss.source_files = 'Classes/**/*.{h,m}'
    ss.dependency 'zMaticoo', '>= 2.3.0'
    ss.dependency 'TPNiOS'
  end

  # Legacy API + TPNiOS（与 Legacy 同代码；用于宿主已接入 TPNiOS 且版本 ≤ 6.4.92）
  s.subspec 'LegacyTPN' do |ss|
    ss.source_files = 'ClassesLegacy/**/*.{h,m}'
    ss.dependency 'zMaticoo', '>= 2.3.0'
    ss.dependency 'TPNiOS', '<= 6.4.92'
  end
end
