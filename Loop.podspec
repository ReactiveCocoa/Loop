Pod::Spec.new do |s|

  s.name          = "Loop"
  s.version       = "3.0.0"
  s.summary       = "Unidirectional reactive architecture"

  s.description   = <<-DESC
                    A unidirectional data flow µframework, built on top of ReactiveSwift.
                    DESC

  s.homepage      = "https://github.com/ReactiveCocoa/Loop/"
  s.license       = { :type => "MIT", :file => "LICENSE" }
  s.author        = "ReactiveCocoa Community"
  s.ios.deployment_target = '11.0'
  s.osx.deployment_target = '10.13'
  s.watchos.deployment_target = '4.0'
  s.tvos.deployment_target = '11.0'
  s.source        = { :git => "https://github.com/ReactiveCocoa/Loop.git", :tag => "#{s.version}" }
  s.source_files  = ["Loop/*.{swift}", "Loop/**/*.{swift}", "Loop/**/**/*.{swift}"]

  s.cocoapods_version = ">= 1.7.0"
  s.swift_versions = ["5.2"]

  s.dependency "ReactiveSwift", "~> 7.0"
end
