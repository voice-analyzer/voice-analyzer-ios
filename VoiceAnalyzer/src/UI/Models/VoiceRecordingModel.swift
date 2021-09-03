import os
import AVFoundation

public struct AnalysisFrame {
    var pitch: Pitch?
    var formants: [Formant]
}

public class VoiceRecordingModel: ObservableObject {
    static let CONFIDENCE_THRESHOLD: Float = 0.20

    @Published var frames: [AnalyzerOutput] = []

    struct RecordingState {
        let activity: AudioSession.Activity
        let engine: AVAudioEngine

        var analyzer: Analyzer? = nil
        var sampleRate: Float64? = nil
        var pitchEstimationAlgorithm: PitchEstimationAlgorithm? = nil
    }

    private var recordingState: RecordingState?

    public var isRecording: Bool {
        get { if let _ = recordingState { return true } else { return false } }
    }

    public func toggleRecording(env: AppEnvironment) throws {
        if let _ = self.recordingState {
            stopRecording(env: env)
        } else {
            try startRecording(env: env)
        }
    }

    public func startRecording(env: AppEnvironment) throws {
        if let _ = self.recordingState {
            stopRecording(env: env)
        }

        os_log("starting recording")

        let activity = AudioSession.Activity(category: .record)
        env.audioSession.startActivity(activity)

        let engine = AVAudioEngine()
        let inputFormat = engine.inputNode.outputFormat(forBus: 0)
        engine.inputNode.installTap(onBus: 0, bufferSize: 512, format: inputFormat) {
            [weak self] (buffer, time) in self?.processData(buffer: buffer, time: time, env: env)
        }

        try engine.start()

        self.recordingState = RecordingState(activity: activity, engine: engine)
    }

    public func stopRecording(env: AppEnvironment) {
        guard let state = self.recordingState else { return }
        recordingState = nil

        os_log("stopping recording")

        state.engine.stop()
        env.audioSession.endActivity(state.activity)
    }

    func processData(buffer: AVAudioPCMBuffer, time: AVAudioTime, env: AppEnvironment) {
        if buffer.format.sampleRate != self.recordingState?.sampleRate {
            if let oldSampleRate = self.recordingState?.sampleRate {
                os_log("sample rate changed from %f to %f", oldSampleRate, buffer.format.sampleRate)
            }
            self.recordingState?.analyzer = nil
            self.recordingState?.sampleRate = buffer.format.sampleRate
        }

        let pitchEstimationAlgorithm: PitchEstimationAlgorithm
        switch env.preferences.pitchEstimationAlgorithm {
        case .IRAPT: pitchEstimationAlgorithm = PitchEstimationAlgorithm.Irapt
        case .Yin:   pitchEstimationAlgorithm = PitchEstimationAlgorithm.Yin
        }

        if pitchEstimationAlgorithm != self.recordingState?.pitchEstimationAlgorithm {
            if let oldPitchEstimationAlgorithm = self.recordingState?.pitchEstimationAlgorithm {
                os_log("pitch estimation algorithm changed from %d to %d",
                       oldPitchEstimationAlgorithm.rawValue,
                       pitchEstimationAlgorithm.rawValue)
            }
            self.recordingState?.analyzer = nil
            self.recordingState?.pitchEstimationAlgorithm = pitchEstimationAlgorithm
        }

        let analyzer = self.recordingState?.analyzer ?? {
            os_log("starting analyzer with pitch estimation algorithm %d and sample rate %f",
                   pitchEstimationAlgorithm.rawValue,
                   buffer.format.sampleRate)
            return Analyzer(
                sampleRate: buffer.format.sampleRate,
                pitchEstimationAlgorithm: pitchEstimationAlgorithm
            )
        }()
        self.recordingState?.analyzer = analyzer

        let output = analyzer.process(
            samples: buffer.floatChannelData!.pointee,
            samplesLen: UInt(buffer.frameLength))
        if output.pitch.confidence > Self.CONFIDENCE_THRESHOLD {
            DispatchQueue.main.async {
                self.frames.append(output)
            }
        }
    }
}
