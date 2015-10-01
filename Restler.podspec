#
# Be sure to run `pod lib lint Restler.podspec' to ensure this is a
# valid spec and remove all comments before submitting the spec.
#
# Any lines starting with a # are optional, but encouraged
#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = "Restler"
  s.version          = "0.0.1"
  s.summary          = "A short description of Restler."
  s.description      = <<-DESC
                       An optional longer description of Restler

                       * Markdown format.
                       * Don't worry about the indent, we strip it!
                       DESC
  s.homepage         = "https://github.com/kildevaeld/restler"

  s.license          = 'MIT'
  s.author           = { "Softshag & Me" => "admin@softshag.dk" }
  s.source           = { :git => "https://github.com/kildevaeld/restler.git", :tag => s.version.to_s }

  s.platform     = :ios, '8.0'
  s.requires_arc = true

  s.default_subspec = 'Core'

  s.subspec 'Core' do |cs|
    cs.source_files = 'Pod/Classes/*'
  end

  s.subspec 'CoreData' do |cd|
     cd.source_files = 'Pod/Classes/CoreData/**/*'
     cd.framework = 'CoreData'
     cd.dependency 'DStack'
     
  end

#s.dependency 'Bolts/Tasks'
  s.dependency 'Alamofire'
  s.dependency 'XCGLogger', '~> 3.0'
  s.dependency 'Promissum', '~> 0.3.0'
  s.dependency 'Promissum/Alamofire', '~> 0.3.0'
  s.dependency 'SwiftyJSON', '~> 2.3.0'
  s.dependency 'ReachabilitySwift', '~> 2.0'
end
