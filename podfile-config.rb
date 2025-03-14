platform :ios, '15.0'

target 'SmartSaver' do
  use_frameworks!
  
  # Firebase
  pod 'Firebase/Core'
  pod 'Firebase/Auth'
  pod 'Firebase/Firestore'
  pod 'Firebase/Analytics'
  
  # UI
  pod 'Charts'
  pod 'lottie-ios'
  
  # Utilities
  pod 'SwiftLint'
end
