Pod::Spec.new do |s|
  s.name             = "PLImageManager"
  s.version          = "1.0.1"
  s.summary          = "Image manager/downloader for iOS"
  s.homepage         = "https://github.com/Polidea/PLImageManager"
  s.license          = { :type => 'BSD', :file => 'LICENSE' }
  s.author           = { "Antoni Kedracki" => "antoni.kedracki@polidea.com" }
  s.source           = { :git => "https://github.com/Polidea/PLImageManager.git", :tag => s.version.to_s }
  s.platform     = :ios, '5.0'
  s.requires_arc = true
  s.source_files = 'PLImageManager/Sources/*.{h,m}'
  s.deprecated = true
  s.deprecated_in_favor_of = 'PLXImageManager'
end
