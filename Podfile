# Uncomment the next line to define a global platform for your project
platform :ios, '11.0'

target 'metawallet' do
  # Comment the next line if you're not using Swift and don't want to use dynamic frameworks
  use_frameworks!
  pod 'GBPing'
  pod 'Alamofire'
  pod 'SwiftyJSON'
  pod 'Fabric'
  pod 'Crashlytics'
  pod 'OneStore'
  pod 'QRCodeReader.swift', '~> 9.0.1'
end

post_install do |installer|
    installer.pods_project.targets.each do |target|
        target.build_configurations.each do |config|
            config.build_settings['ENABLE_BITCODE'] = 'NO'
        end
    end
end
