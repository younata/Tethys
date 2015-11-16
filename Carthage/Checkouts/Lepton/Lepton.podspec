Pod::Spec.new do |s|
  s.name         = "Lepton"
  s.version      = "0.1.0"
  s.summary      = "An RSS/Atom Parser in Swift."

  s.homepage     = "https://github.com/younata/Lepton"
  s.license      = { :type => "MIT", :file => "LICENSE" }

  s.author       = "Rachel Brindle"
  s.ios.deployment_target = "8.3"

  s.source       = { :git => "https://github.com/younata/Lepton.git", :tag => "v0.1.0" }
  s.source_files  = "Lepton", "Lepton/**/*.{swift,h,m}"

  s.framework = "XCTest"
  s.requires_arc = true
end

