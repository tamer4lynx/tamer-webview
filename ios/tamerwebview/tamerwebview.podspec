package = JSON.parse(File.read(File.join(__dir__, "..", "..", "package.json")))

Pod::Spec.new do |s|
  s.name             = 'tamerwebview'
  s.version          = package["version"]
  s.module_name      = 'tamerwebview'
  s.summary          = 'Embedded WebView Lynx custom element (WKWebView).'
  s.description      = 'Registers the webview Lynx element for iOS (WKWebView).'
  s.homepage         = 'https://github.com/tamer4lynx/tamer4lynx'
  s.license          = package["license"]
  s.authors          = package["author"]
  s.source           = { :path => '.' }
  s.ios.deployment_target = '13.0'
  s.source_files     = 'tamerwebview/Classes/**/*.{h,m}'
  s.public_header_files = 'tamerwebview/Classes/**/*.h'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.dependency 'Lynx'
  s.frameworks       = 'WebKit'
  s.requires_arc     = true
end
