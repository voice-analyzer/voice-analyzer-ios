import os
import AVFoundation
import VoiceAnalyzerRust

public struct AnalysisFrame {
    var pitch: Pitch?
    var formants: [Formant]
}

public class VoiceRecordingModel: ObservableObject {
    static let THRESHOLD: Float = 0.20
    static let FORMANT_SAFETY_MARGIN: Float64 = 50.0

    @Published var frames: [AnalyzerOutput] = []

    var analyzer: Analyzer? = nil;
    var sampleRate: Float64? = nil;

    struct RecordingState {
        let activity: AudioSession.Activity
        let engine: AVAudioEngine
    }

    private var recordingState: RecordingState?

    public var isRecording: Bool {
        get { if let _ = recordingState { return true } else { return false } }
    }

    public func toggleRecording(env: Environment) throws {
        if let _ = self.recordingState {
            stopRecording(env: env)
        } else {
            try startRecording(env: env)
        }
    }

    public func startRecording(env: Environment) throws {
        if let _ = self.recordingState {
            stopRecording(env: env)
        }

        os_log("starting recording")

        let activity = AudioSession.Activity(category: .record)
        env.audioSession.startActivity(activity)

        let engine = AVAudioEngine()
        let inputFormat = engine.inputNode.outputFormat(forBus: 0)
        engine.inputNode.installTap(onBus: 0, bufferSize: 512, format: inputFormat) {
            [weak self] (buffer, time) in self?.processData(buffer: buffer, time: time)
        }

        try engine.start()

        self.recordingState = RecordingState(activity: activity, engine: engine)
    }

    public func stopRecording(env: Environment) {
        guard let state = self.recordingState else { return }
        recordingState = nil

        os_log("stopping recording")

        state.engine.stop()
        env.audioSession.endActivity(state.activity)
    }

    func processData(buffer: AVAudioPCMBuffer, time: AVAudioTime) {
        if buffer.format.sampleRate != self.sampleRate {
            if let oldSampleRate = self.sampleRate {
                os_log("sample rate changed from %f to %f", oldSampleRate, buffer.format.sampleRate)
            } else {
                os_log("starting analyzer with sample rate %f", buffer.format.sampleRate)
            }
            self.analyzer = nil
            self.sampleRate = buffer.format.sampleRate
        }
        let analyzer = self.analyzer ?? Analyzer(sampleRate: buffer.format.sampleRate)
        self.analyzer = analyzer

        let output = analyzer.process(
            samples: buffer.floatChannelData!.pointee,
            samplesLen: UInt(buffer.frameLength))
        if output.pitch.confidence > Self.THRESHOLD {
            DispatchQueue.main.async {
                self.frames.append(output)
            }
        }
    }
}
