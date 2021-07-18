import libvoice_analyzer_rust

public typealias Pitch = libvoice_analyzer_rust.Pitch

public func yin(samples: UnsafePointer<Float>, samplesLen: UInt, sampleRate: UInt32, threshold: Float) -> Pitch {
    return voice_analyzer_rust_yin(samples, samplesLen, sampleRate, threshold)
}
