Pod::Spec.new do |s|
  s.name = 'ESPasscodeLock'
  s.module_name = 'PasscodeLock'
  s.version = '5.0.1'
  s.swift_version = '5.0'
  s.ios.deployment_target = '8.0'
  s.license = { type: 'MIT', file: 'LICENSE.txt' }
  s.summary = 'An iOS passcode lock with Touch ID authentication written in Swift.'
  s.homepage = 'https://github.com/erickyim/SwiftPasscodeLock'
  s.authors = { 'Oskari Rauta' => '', 'Yanko Dimitrov' => '', 'Chris Ziogas' => '' }
  s.source = { git: 'https://github.com/erickyim/SwiftPasscodeLock.git', tag: 'v5.0.1' }

  s.source_files = 'PasscodeLock/*.{h,swift}',
                   'PasscodeLock/*/*.{swift}'

  s.resources = [
    'PasscodeLock/Views/PasscodeLockView.xib',
    'PasscodeLock/Views/DarkPasscodeLockView.xib',
    'PasscodeLock/en.lproj/*'
  ]
  s.ios.framework = 'LocalAuthentication'
  s.requires_arc = true
end
