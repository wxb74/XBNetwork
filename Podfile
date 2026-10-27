source 'https://cdn.cocoapods.org/'
platform :ios, '15.0'

project 'XBNetworkDemo.xcodeproj'

target 'XBNetworkDemo' do
  # AFNetworking/Serialization 由 podspec 声明。
  pod 'XBNetwork', :path => '.'

  target 'XBNetworkTests' do
    inherit! :search_paths
  end
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
    end
  end
end

# 显式依赖 Pods 聚合目标，避免只构建 App 时遗漏静态库。
# CocoaPods 完成集成后更新，pod install 重新生成工程时也会保留。
post_integrate do |installer|
  projects = []
  installer.aggregate_targets.each do |aggregate|
    project = aggregate.user_project
    pods_target = installer.pods_project.targets.find { |target| target.name == aggregate.label }
    next unless pods_target

    unless project.reference_for_path(installer.pods_project.path)
      group = project.main_group.find_subpath('Pods', false) || project.main_group
      group.new_file(installer.pods_project.path)
    end
    aggregate.user_targets.each { |target| target.add_dependency(pods_target) }
    projects << project
  end
  projects.uniq.each do |project|
    # 与 Pods 的 Debug 架构保持一致，避免 App 构建 x86_64 而依赖只构建 arm64。
    project.build_configurations.each do |config|
      config.build_settings['ONLY_ACTIVE_ARCH'] = 'YES' if config.name == 'Debug'
    end
    project.save
  end
end
