import libvoice_analyzer_rust

public typealias Pitch = libvoice_analyzer_rust.Pitch
public typealias Formant = libvoice_analyzer_rust.Formant
public typealias AnalyzerOutput = libvoice_analyzer_rust.AnalyzerOutput
public typealias PitchEstimationAlgorithm = libvoice_analyzer_rust.PitchEstimationAlgorithm
public typealias FormantEstimationAlgorithm = libvoice_analyzer_rust.FormantEstimationAlgorithm

extension PitchEstimationAlgorithm: Hashable {
    public static let Irapt = libvoice_analyzer_rust.PitchEstimationAlgorithm_Irapt
    public static let Yin = libvoice_analyzer_rust.PitchEstimationAlgorithm_Yin
}

extension FormantEstimationAlgorithm: Hashable {
    public static let None = libvoice_analyzer_rust.FormantEstimationAlgorithm_None
    public static let LibFormants = libvoice_analyzer_rust.FormantEstimationAlgorithm_LibFormants
}

public class Analyzer {
    let analyzer: OpaquePointer

    public init(sampleRate: Float64,
                pitchEstimationAlgorithm: PitchEstimationAlgorithm,
                formantEstimationAlgorithm: FormantEstimationAlgorithm) {
        analyzer = voice_analyzer_rust_analyzer_new(sampleRate, pitchEstimationAlgorithm, formantEstimationAlgorithm)
    }

    deinit {
        voice_analyzer_rust_analyzer_drop(analyzer)
    }

    public func process(samples: UnsafePointer<Float>, samplesLen: UInt) -> AnalyzerOutput {
        voice_analyzer_rust_analyzer_process(analyzer, samples, samplesLen)
    }

    public func reset() {
        voice_analyzer_rust_analyzer_reset(analyzer)
    }
}
