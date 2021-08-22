import libvoice_analyzer_rust

public typealias Pitch = libvoice_analyzer_rust.Pitch
public typealias Formant = libvoice_analyzer_rust.Formant
public typealias AnalyzerOutput = libvoice_analyzer_rust.AnalyzerOutput

public func yin(samples: UnsafePointer<Float>, samplesLen: UInt, sampleRate: UInt32, threshold: Float) -> Pitch {
    return voice_analyzer_rust_yin(samples, samplesLen, sampleRate, threshold)
}

public class Analyzer {
    let analyzer: OpaquePointer

    public init(sampleRate: Float64) {
        analyzer = voice_analyzer_rust_analyzer_new(sampleRate)
    }

    deinit {
        voice_analyzer_rust_analyzer_drop(analyzer)
    }

    public func process(samples: UnsafePointer<Float>, samplesLen: UInt) -> AnalyzerOutput {
        voice_analyzer_rust_analyzer_process(analyzer, samples, samplesLen)
    }
}
