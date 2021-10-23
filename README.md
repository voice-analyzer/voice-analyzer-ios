# Voice Analyzer

Voice Analyzer is a free and open source voice analysis app specifically geared toward aiding voice pitch and resonance
training.

## Contributing Bug Reports

GitHub is the project's bug tracker. Please [search](https://github.com/voice-analyzer/voice-analyzer-ios/issues) for similar existing issues before [submitting a new one](https://github.com/voice-analyzer/voice-analyzer-ios/issues/new).

## Building

Make sure Rust version 1.55.0 or newer is installed with the desired toolchain targets. The Rust target names for the
supported build targets are:

* iPhone on x86_64: `x86_64-apple-ios`
* iPhone on 64-bit ARM: `aarch64-apple-ios`
* iPhone Simulator on 64-bit ARM (e.g. M1 processor): `aarch64-apple-ios-sim` (available in 1.56.0 or newer)

One can update Rust and install toolchain targets with [`rustup`](https://rustup.rs/):

```
$ rustup update
$ rustup target install x86_64-apple-ios aarch64-apple-ios aarch64-apple-ios-sim
```

Open the `VoiceAnalyzer.xcworkspace` in Xcode.

```
$ open VoiceAnalyzer.xcworkspace
```

In the Project Settings Editor, select the VoiceAnalyzer target, navigate to the Signing & Capabilities tab, and select your own Team for signing. Xcode must be logged in to an Apple Developer account.

Then build and run the app.

## License

Licensed under [MIT](https://opensource.org/licenses/MIT).
