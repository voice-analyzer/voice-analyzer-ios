import os
import AVFoundation

public struct AnalysisFrame {
    var pitch: Pitch?
    var formants: [Formant]
}

public class VoiceRecordingModel: ObservableObject {
    static let CONFIDENCE_THRESHOLD: Float = 0.20
    static let HEADER_LENGTH: UInt = WaveHeader.encodedLength(dataFormat: .IEEEFloat)

    @Published var frames: [AnalyzerOutput] = []

    struct RecordingState {
        let activity: AudioSession.Activity
        let engine: AVAudioEngine

        var analyzer: Analyzer? = nil
        var sampleRate: Float64? = nil
        var pitchEstimationAlgorithm: PitchEstimationAlgorithm? = nil
        var formantEstimationAlgorithm: FormantEstimationAlgorithm? = nil
    }

    struct RecordingFileState {
        let handle: FileHandle

        var sampleRate: Float64? = nil
        var samples: UInt64 = 0
    }

    private var recordingState: RecordingState?
    private var recordingFile: RecordingFileState?

    private let recordingDispatchQueue = DispatchQueue(label: "Voice Recording")

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

        _ = openRecordingFile()

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

    public func clearRecording() {
        frames = []
        recordingFile = nil
        _ = openRecordingFile()
    }

    public func saveRecording(env: AppEnvironment) throws {
        try recordingDispatchQueue.sync {
            try saveRecordingOnCurrentThread(env: env)
        }
    }

    private func saveRecordingOnCurrentThread(env: AppEnvironment) throws {
        guard let recordingFile = recordingFile else { return }
        guard let sampleRate = recordingFile.sampleRate else { return }
        let dateNow = Date()

        let liveRecordingFileUrl: URL
        let destRecordingFileUrl: URL
        let recordingFileSize: UInt64
        do {
            liveRecordingFileUrl = try AppFilesystem.appLiveRecordingFile()
            let formattedDateNow = ISO8601DateFormatter().string(from: dateNow)
            destRecordingFileUrl = try AppFilesystem.appRecordingDirectory().appendingPathComponent("Recording at \(formattedDateNow).wav")
            recordingFileSize = recordingFile.handle.offsetInFile
        } catch {
            os_log("error calculating paths for recording file: %@", error.localizedDescription)
            return
        }

        let recordingRecord = DatabaseRecords.Recording(
            timestamp: dateNow,
            length: Double(recordingFile.samples) / sampleRate,
            filename: destRecordingFileUrl.lastPathComponent,
            fileSize: Int64(recordingFileSize))

        let waveHeader = WaveHeader(
            dataLength: UInt32(recordingFileSize) - UInt32(Self.HEADER_LENGTH),
            dataFormat: .IEEEFloat,
            channelCount: 1,
            sampleRate: UInt32(sampleRate),
            bytesPerSample: 4)

        do {
            recordingFile.handle.seek(toFileOffset: 0)
            try recordingFile.handle.write(contentsOf: waveHeader.encode())
        } catch {
            os_log("error writing WAVE header to recording file: %@", error.localizedDescription)
        }

        do {
            try FileManager.default.moveItem(at: liveRecordingFileUrl, to: destRecordingFileUrl)
        } catch {
            os_log("error moving recording file: %@", error.localizedDescription)
        }

        try env.databaseStorage.writer().write { db in
            try recordingRecord.insert(db)
        }
        os_log("saved recording file: %@", destRecordingFileUrl.relativeString)

        clearRecording()
    }

    func openRecordingFile() -> RecordingFileState? {
        if let recordingFile = recordingFile { return recordingFile }
        do {
            let recordingFileUrl = try AppFilesystem.appLiveRecordingFile()
            FileManager.default.createFile(atPath: recordingFileUrl.path, contents: nil)
            let recordingFile = RecordingFileState(handle: try FileHandle(forWritingTo: recordingFileUrl))
            try recordingFile.handle.truncate(atOffset: 0)
            try recordingFile.handle.write(contentsOf: Data(count: Int(Self.HEADER_LENGTH)))
            self.recordingFile = recordingFile
            return recordingFile
        } catch {
            os_log("error opening live recording file: %@", error.localizedDescription)
            return nil
        }
    }

    func processData(buffer: AVAudioPCMBuffer, time: AVAudioTime, env: AppEnvironment) {
        var sampleRateChanged = false
        if buffer.format.sampleRate != self.recordingState?.sampleRate {
            if let oldSampleRate = self.recordingState?.sampleRate {
                os_log("sample rate changed from %f to %f", oldSampleRate, buffer.format.sampleRate)
            }
            self.recordingState?.analyzer = nil
            self.recordingState?.sampleRate = buffer.format.sampleRate
        }

        if buffer.format.sampleRate != self.recordingFile?.sampleRate {
            if let oldSampleRate = self.recordingFile?.sampleRate {
                sampleRateChanged = true
                os_log("sample rate for recording changed from %f to %f", oldSampleRate, buffer.format.sampleRate)
            }
            self.recordingFile?.sampleRate = buffer.format.sampleRate
        }

        writeData(buffer: buffer, time: time, sampleRateChanged: sampleRateChanged)

        let pitchEstimationAlgorithm: PitchEstimationAlgorithm
        switch env.preferences.pitchEstimationAlgorithm {
        case .IRAPT: pitchEstimationAlgorithm = PitchEstimationAlgorithm.Irapt
        case .Yin:   pitchEstimationAlgorithm = PitchEstimationAlgorithm.Yin
        }

        let formantEstimationAlgorithm = env.preferences.formantEstimationEnabled ? FormantEstimationAlgorithm.LibFormants : .None

        if pitchEstimationAlgorithm != self.recordingState?.pitchEstimationAlgorithm {
            if let oldPitchEstimationAlgorithm = self.recordingState?.pitchEstimationAlgorithm {
                os_log("pitch estimation algorithm changed from %d to %d",
                       oldPitchEstimationAlgorithm.rawValue,
                       pitchEstimationAlgorithm.rawValue)
            }
            self.recordingState?.analyzer = nil
            self.recordingState?.pitchEstimationAlgorithm = pitchEstimationAlgorithm
        }

        if formantEstimationAlgorithm != self.recordingState?.formantEstimationAlgorithm {
            if let oldFormantEstimationAlgorithm = self.recordingState?.formantEstimationAlgorithm {
                os_log("formant estimation algorithm changed from %d to %d",
                       oldFormantEstimationAlgorithm.rawValue,
                       formantEstimationAlgorithm.rawValue)
            }
            self.recordingState?.analyzer = nil
            self.recordingState?.formantEstimationAlgorithm = formantEstimationAlgorithm
        }

        let analyzer = self.recordingState?.analyzer ?? {
            os_log("starting analyzer with pitch estimation algorithm %d and sample rate %f",
                   pitchEstimationAlgorithm.rawValue,
                   buffer.format.sampleRate)
            return Analyzer(
                sampleRate: buffer.format.sampleRate,
                pitchEstimationAlgorithm: pitchEstimationAlgorithm,
                formantEstimationAlgorithm: formantEstimationAlgorithm
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

    func writeData(buffer: AVAudioPCMBuffer, time: AVAudioTime, sampleRateChanged: Bool) {
        guard let recordingFile = recordingFile else { return }

        recordingDispatchQueue.async {
            if sampleRateChanged {
                do {
                    try recordingFile.handle.truncate(atOffset: UInt64(Self.HEADER_LENGTH))
                    self.recordingFile?.samples = 0
                } catch {
                    os_log("error truncating live recording file: %@", error.localizedDescription)
                }
            }

            let data = Data(UnsafeRawBufferPointer(start: buffer.floatChannelData!.pointee, count: Int(buffer.frameLength * 4)))
            do {
                try recordingFile.handle.write(contentsOf: data)
                self.recordingFile?.samples += UInt64(buffer.frameLength)
            } catch {
                os_log("error writing to live recording file: %@", error.localizedDescription)
            }
        }
    }
}
