import libvoice_analyzer_rust

public typealias Pitch = libvoice_analyzer_rust.Pitch

public func yin(samples: UnsafePointer<Float>, samplesLen: UInt, sampleRate: UInt32, threshold: Float) -> Pitch {
    return voice_analyzer_rust_yin(samples, samplesLen, sampleRate, threshold)
}

public class IRAPT {
    let irapt: OpaquePointer

    public init(sampleRate: Float64) {
        irapt = voice_analyzer_rust_irapt_new(sampleRate)
    }

    deinit {
        voice_analyzer_rust_irapt_drop(irapt)
    }

    public func process(samples: UnsafePointer<Float>, samplesLen: UInt) -> Pitch {
        return voice_analyzer_rust_irapt_process(irapt, samples, samplesLen)
    }
}
