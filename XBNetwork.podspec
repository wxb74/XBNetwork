Pod::Spec.new do |s|
  s.name = 'XBNetwork'
  s.version = '0.1.0'
  s.summary = 'Explicit Objective-C HTTP requests built on NSURLSession.'
  s.description = 'Configurable Query, Form, JSON, Raw and Multipart requests, isolated cookies, upload progress, total deadlines and structured errors.'
  s.homepage = 'https://github.com/wxb74/XBNetwork'
  s.license = { :type => 'MIT', :file => 'LICENSE' }
  s.author = { 'wxb74' => '20829102+wxb74@users.noreply.github.com' }
  s.source = { :git => 'https://github.com/wxb74/XBNetwork.git', :tag => "v#{s.version}" }
  s.ios.deployment_target = '15.0'
  s.requires_arc = true
  s.source_files = 'XBNetwork/**/*.{h,m}'
  s.public_header_files = 'XBNetwork/Public/*.h', 'XBNetwork/XBNetworkUmbrella.h'
  s.private_header_files = 'XBNetwork/Internal/*.h'
  s.header_mappings_dir = 'XBNetwork'
  s.module_name = 'XBNetwork'
  s.frameworks = 'Foundation'
  s.dependency 'AFNetworking/Serialization', '~> 4.0.1'
end
