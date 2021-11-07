import libvoice_analyzer_rust

public typealias Pitch = libvoice_analyzer_rust.Pitch
public typealias Formant = libvoice_analyzer_rust.Formant
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
        AnalyzerOutput(output: voice_analyzer_rust_analyzer_process(analyzer, samples, samplesLen))
    }

    public func reset() {
        voice_analyzer_rust_analyzer_reset(analyzer)
    }
}

public class AnalyzerOutput {
    var pitches: Pitches { Pitches(output: self) }
    var formants: (Formant, Formant) { output.formants }

    private let output: libvoice_analyzer_rust.AnalyzerOutput
    private var raw_pitches: UnsafeBufferPointer<Pitch> {
        UnsafeBufferPointer(start: output.pitches, count: Int(output.pitches_len))
    }

    class Pitches: Sequence {
        let output: AnalyzerOutput

        class Iterator: IteratorProtocol {
            let pitches: Pitches
            var iterator: UnsafeBufferPointer<Pitch>.Iterator
            fileprivate init(pitches: Pitches) {
                self.pitches = pitches
                iterator = pitches.output.raw_pitches.makeIterator()
            }

            func next() -> Pitch? {
                iterator.next()
            }
        }

        fileprivate init(output: AnalyzerOutput) {
            self.output = output

        }

        func makeIterator() -> Iterator {
            Iterator(pitches: self)
        }
    }

    fileprivate init(output: libvoice_analyzer_rust.AnalyzerOutput) {
        self.output = output
    }

    deinit {
        voice_analyzer_rust_analyzer_output_drop(output)
    }
}
