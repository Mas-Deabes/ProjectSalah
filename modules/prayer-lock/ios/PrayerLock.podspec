Pod::Spec.new do |s|
  s.name             = 'PrayerLock'
  s.version          = '1.0.0'
  s.summary          = 'Screen Time lock for ProjectSalah'
  s.description      = 'Applies and removes Screen Time shields for ProjectSalah'
  s.author           = 'Sif'
  s.homepage         = 'https://github.com/Mas-Deabes/ProjectSalah'
  s.license          = 'MIT'
  s.platforms        = { :ios => '16.0' }
  s.source           = { git: '' }
  s.static_framework = true
  s.swift_version    = '5.9'

  s.dependency 'ExpoModulesCore'

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.source_files = '**/*.swift'
  s.frameworks = 'FamilyControls', 'ManagedSettings', 'DeviceActivity', 'SwiftUI'
endye