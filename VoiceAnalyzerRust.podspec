Pod::Spec.new do |s|
  s.name             = 'VoiceAnalyzerRust'
  s.version          = '0.1.0'
  s.summary          = 'Rust code for the VoiceAnalyzer project.'
  s.homepage         = 'https://github.com/voice-analyzer/voice-analyzer-ios'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'jessa0' => 'git@jessa0.com' }
  s.source           = { :git => 'https://github.com/voice-analyzer/voice-analyzer-ios.git', :tag => "#{s.version}" }

  s.swift_version = '5'
  s.platform = :ios, '10'
  s.ios.deployment_target = '9.0'

  s.source_files = 'VoiceAnalyzerRust/Sources/**/*.{m,swift}'
  s.preserve_paths = [
    'VoiceAnalyzerRust/Sources/libvoice_analyzer_rust',
  ]

  s.pod_target_xcconfig = {
      'HEADER_SEARCH_PATHS' => '$(PODS_TARGET_SRCROOT)/VoiceAnalyzerRust/Sources/libvoice_analyzer_rust',
      'SWIFT_INCLUDE_PATHS' => '$(HEADER_SEARCH_PATHS)',

      # Make sure we link the static library, not a dynamic one.
      # Use an extra level of indirection because CocoaPods messes with OTHER_LDFLAGS too.
      'LIBVOICE_ANALYZER_RUST_FFI_LIB_IF_NEEDED' => '$(PODS_TARGET_SRCROOT)/target/$(CARGO_BUILD_TARGET)/release/libvoice_analyzer_rust.a',
      'OTHER_LDFLAGS' => '$(LIBVOICE_ANALYZER_RUST_FFI_LIB_IF_NEEDED)',

      'CARGO_BUILD_TARGET[sdk=iphonesimulator*][arch=arm64]' => 'aarch64-apple-ios-sim',
      'CARGO_BUILD_TARGET[sdk=iphonesimulator*][arch=*]' => 'x86_64-apple-ios',
      'CARGO_BUILD_TARGET[sdk=iphoneos*]' => 'aarch64-apple-ios',
      # Presently, there's no special SDK or arch for maccatalyst,
      # so we need to hackily use the "IS_MACCATALYST" build flag
      # to set the appropriate cargo target
      'CARGO_BUILD_TARGET_MAC_CATALYST_ARM_' => 'aarch64-apple-darwin',
      'CARGO_BUILD_TARGET_MAC_CATALYST_ARM_YES' => 'aarch64-apple-ios-macabi',
      'CARGO_BUILD_TARGET[sdk=macosx*][arch=arm64]' => '$(CARGO_BUILD_TARGET_MAC_CATALYST_ARM_$(IS_MACCATALYST))',
      'CARGO_BUILD_TARGET_MAC_CATALYST_X86_' => 'x86_64-apple-darwin',
      'CARGO_BUILD_TARGET_MAC_CATALYST_X86_YES' => 'x86_64-apple-ios-macabi',
      'CARGO_BUILD_TARGET[sdk=macosx*][arch=*]' => '$(CARGO_BUILD_TARGET_MAC_CATALYST_X86_$(IS_MACCATALYST))',

      'ARCHS[sdk=iphonesimulator*]' => 'x86_64 arm64',
      'ARCHS[sdk=iphoneos*]' => 'arm64',
  }


  s.script_phases = [
    {
      :name => 'Build libvoice_analyzer_rust',
      :execution_position => :before_compile,
      :output_files => ['target/universal/release/libvoice_analyzer_rust.a'],
      :script => %q(
          make -C ${PODS_TARGET_SRCROOT} rust-build-universal CARGO="${CARGO:-$HOME/.cargo/bin/cargo}"
      ),
    }
  ]
end
