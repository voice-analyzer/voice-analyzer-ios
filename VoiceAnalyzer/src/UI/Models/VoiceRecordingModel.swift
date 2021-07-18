import os
import AVFoundation
import VoiceAnalyzerRust

public class VoiceRecordingModel: ObservableObject {
    static let THRESHOLD: Float = 0.20

    @Published var pitches: [Pitch] = []

    struct RecordingState {
        let activity: AudioSession.Activity
        let engine: AVAudioEngine
    }

    private var recordingState: RecordingState?

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
        let pitch = VoiceAnalyzerRust.yin(
            samples: buffer.floatChannelData!.pointee,
            samplesLen: UInt(buffer.frameLength),
            sampleRate: UInt32(buffer.format.sampleRate),
            threshold: Self.THRESHOLD)
        if pitch.confidence > Self.THRESHOLD {
            DispatchQueue.main.async {
                self.pitches.append(pitch)
            }
        }
    }
}
