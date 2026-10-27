#!/usr/bin/env ruby
# Same minimum-deployment adjustment as the Demo Podfile. Does not change source,
# skip builds/import checks, or patch the installed AFNetworking podspec.
require 'cocoapods'
module XBNetworkValidationDeployment
  def install_pod
    super
    @installer.pods_project.targets.each do |target|
      target.build_configurations.each do |config|
        current = config.build_settings['IPHONEOS_DEPLOYMENT_TARGET']
        if current && Gem::Version.new(current) < Gem::Version.new('15.0')
          config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
        end
      end
    end
    @installer.pods_project.save
  end
end
Pod::Validator.prepend(XBNetworkValidationDeployment)
Dir.chdir(File.expand_path('..', __dir__)) do
  Pod::Command.run(['lib', 'lint', 'XBNetwork.podspec', '--allow-warnings', '--use-libraries'] + ARGV)
end
