import AVFoundation
import Combine
import Foundation
import os

class VoiceRecorderModel: ObservableObject {
    private struct RecordingState {
        let activity: AudioSession.Activity
        let engine: AVAudioEngine
        let audioPacketsSink: AnyCancellable
    }

    private var recordingState: RecordingState?
    private var processorQueue = DispatchQueue(label: "VoiceRecorderModel.processorQueue", qos: .userInitiated)

    var isRecording: Bool {
        if let _ = recordingState { return true } else { return false }
    }

    func toggle(env: AppEnvironment, recording: VoiceRecordingModel) throws {
        if let _ = self.recordingState {
            stop(env: env)
        } else {
            try start(env: env, recording: recording)
        }
    }

    func start(env: AppEnvironment, recording: VoiceRecordingModel) throws {
        if let _ = self.recordingState {
            stop(env: env)
        }

        os_log("starting recording")

        let activity = AudioSession.Activity(category: .record)
        env.audioSession.startActivity(activity)

        let audioPacketProcessor = AudioPacketProcessor()
        let audioPackets = PassthroughSubject<AudioPacket, Never>()
        let audioPacketsSink =
            audioPackets
            .buffer(size: 5, prefetch: .byRequest, whenFull: .dropOldest)
            .receive(on: processorQueue)
            .sink { packet in audioPacketProcessor.process(packet: packet, env: env, recording: recording) }

        let engine = AVAudioEngine()
        let inputFormat = engine.inputNode.outputFormat(forBus: 0)
        var sequenceNumber: UInt64 = 0
        engine.inputNode.installTap(onBus: 0, bufferSize: 512, format: inputFormat) { (buffer, time) in
            let data = Array(UnsafeBufferPointer(start: buffer.floatChannelData!.pointee, count: Int(buffer.frameLength)))
            audioPackets.send(AudioPacket(sequenceNumber: sequenceNumber, data: data, format: buffer.format))
            sequenceNumber += 1
        }

        recording.open()

        try engine.start()

        self.recordingState = RecordingState(activity: activity, engine: engine, audioPacketsSink: audioPacketsSink)
    }

    func stop(env: AppEnvironment) {
        guard let state = self.recordingState else { return }
        recordingState = nil

        os_log("stopping recording")

        state.engine.stop()
        env.audioSession.endActivity(state.activity)
    }
}

private struct AudioPacket {
    let sequenceNumber: UInt64
    let data: [Float]
    let format: AVAudioFormat
}

private class AudioPacketProcessor {
    private struct AnalyzerState {
        var analyzer: Analyzer
        var sampleRate: Float64
        var pitchEstimationAlgorithm: PitchEstimationAlgorithm
        var formantEstimationAlgorithm: FormantEstimationAlgorithm
    }

    private var analyzerState: AnalyzerState?
    private var nextSequenceNumber: UInt64 = 0

    func process(packet: AudioPacket, env: AppEnvironment, recording: VoiceRecordingModel) {
        let analyzer = prepareAnalyzer(sampleRate: packet.format.sampleRate, env: env)

        if packet.sequenceNumber != nextSequenceNumber {
            let missedPackets = packet.sequenceNumber - nextSequenceNumber
            os_log("resetting analyzer due to \(missedPackets) missed packets")
            analyzer.reset()
            nextSequenceNumber = packet.sequenceNumber
        }
        nextSequenceNumber += 1

        recording.writeData(data: packet.data, sampleRate: packet.format.sampleRate)

        let output = packet.data.withUnsafeBufferPointer { buffer -> AnalyzerOutput? in
            guard let baseAddress = buffer.baseAddress else { return nil }
            return analyzer.process(
                samples: baseAddress,
                samplesLen: UInt(buffer.count)
            )
        }
        if let output = output {
            recording.appendFrame(output: output)
        }
    }

    private func prepareAnalyzer(sampleRate: Double, env: AppEnvironment) -> Analyzer {
        var analyzerState = self.analyzerState

        if sampleRate != analyzerState?.sampleRate {
            if let oldSampleRate = analyzerState?.sampleRate {
                os_log("sample rate changed from \(oldSampleRate) to \(sampleRate)")
            }
            analyzerState = nil
        }

        let pitchEstimationAlgorithm: PitchEstimationAlgorithm
        switch env.preferences.pitchEstimationAlgorithm {
        case .IRAPT: pitchEstimationAlgorithm = PitchEstimationAlgorithm.Irapt
        case .Yin: pitchEstimationAlgorithm = PitchEstimationAlgorithm.Yin
        }

        let formantEstimationAlgorithm = env.preferences.formantEstimationEnabled ? FormantEstimationAlgorithm.LibFormants : .None

        if pitchEstimationAlgorithm != analyzerState?.pitchEstimationAlgorithm {
            if let oldPitchEstimationAlgorithm = analyzerState?.pitchEstimationAlgorithm {
                os_log(
                    """
                    pitch estimation algorithm changed \
                    from \(oldPitchEstimationAlgorithm.rawValue) \
                    to \(pitchEstimationAlgorithm.rawValue)
                    """)
            }
            analyzerState = nil
        }

        if formantEstimationAlgorithm != analyzerState?.formantEstimationAlgorithm {
            if let oldFormantEstimationAlgorithm = analyzerState?.formantEstimationAlgorithm {
                os_log(
                    """
                    formant estimation algorithm changed \
                    from \(oldFormantEstimationAlgorithm.rawValue) \
                    to \(formantEstimationAlgorithm.rawValue)
                    """)
            }
            analyzerState = nil
        }

        let analyzer =
            analyzerState?.analyzer
            ?? {
                os_log(
                    "starting analyzer with pitch estimation algorithm \(pitchEstimationAlgorithm.rawValue) and sample rate \(sampleRate)")
                return Analyzer(
                    sampleRate: sampleRate,
                    pitchEstimationAlgorithm: pitchEstimationAlgorithm,
                    formantEstimationAlgorithm: formantEstimationAlgorithm
                )
            }()

        self.analyzerState = AnalyzerState(
            analyzer: analyzer,
            sampleRate: sampleRate,
            pitchEstimationAlgorithm: pitchEstimationAlgorithm,
            formantEstimationAlgorithm: formantEstimationAlgorithm
        )

        return analyzer
    }
}
