import os
import AVFoundation
import Combine

struct AnalysisFrame {
    var time: Float
    var pitchFrequency: Float
    var pitchConfidence: Float
    var firstFormantFrequency: Float?
    var secondFormantFrequency: Float?

    var formantFrequencies: [Float] {
        [firstFormantFrequency, secondFormantFrequency].compactMap { $0 }
    }

    var databaseRecord: DatabaseRecords.AnalysisFrame {
        DatabaseRecords.AnalysisFrame(
            analysisId: -1,
            time: time,
            pitchFrequency: pitchFrequency,
            pitchConfidence: pitchConfidence,
            firstFormantFrequency: firstFormantFrequency,
            secondFormantFrequency: secondFormantFrequency
        )
    }

    static func from(databaseRecord: DatabaseRecords.AnalysisFrame) -> Self? {
        guard let pitchFrequency = databaseRecord.pitchFrequency else { return nil }
        guard let pitchConfidence = databaseRecord.pitchConfidence else { return nil }
        return Self(
            time: databaseRecord.time,
            pitchFrequency: pitchFrequency,
            pitchConfidence: pitchConfidence,
            firstFormantFrequency: databaseRecord.firstFormantFrequency,
            secondFormantFrequency: databaseRecord.secondFormantFrequency
        )
    }
}

struct VoiceRecordingMetadata {
    let lowerLimitLine: Double?
    let upperLimitLine: Double?

    let pitchEstimationAlgorithm: PitchEstimationAlgorithm? = nil
    let formantEstimationAlgorithm: FormantEstimationAlgorithm? = nil
}

class VoiceRecordingModel: ObservableObject {
    static let HEADER_LENGTH: UInt = WaveHeader.encodedLength(dataFormat: .IEEEFloat)

    enum FramesUpdate {
        case append(Append)
        case clear

        struct Append {
            let frame: AnalysisFrame
            let tentativeFrames: [AnalysisFrame]
        }
    }

    let frames = PassthroughSubject<FramesUpdate, Never>()

    private struct RecordingFileState {
        let handle: FileHandle

        var sampleRate: Float64? = nil
        var samples: UInt64 = 0
    }

    private var recordingFile: RecordingFileState?
    private var databaseFrames: [DatabaseRecords.AnalysisFrame] = []

    private let dispatchQueue = DispatchQueue(label: "VoiceRecordingModel", target: .global(qos: .userInitiated))

    func save(env: AppEnvironment, metadata: VoiceRecordingMetadata) throws {
        dispatchPrecondition(condition: .notOnQueue(dispatchQueue))

        try dispatchQueue.sync {
            try saveOnCurrentThread(env: env, metadata: metadata)
            clearOnCurrentThread()
        }
    }

    private func saveOnCurrentThread(env: AppEnvironment, metadata: VoiceRecordingMetadata) throws {
        dispatchPrecondition(condition: .onQueue(dispatchQueue))

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
        } catch let error {
            os_log("error calculating paths for recording file \(error.localizedDescription)")
            return
        }

        var recordingRecord = DatabaseRecords.Recording(
            timestamp: dateNow,
            length: Double(recordingFile.samples) / sampleRate,
            filename: destRecordingFileUrl.lastPathComponent,
            fileSize: Int64(recordingFileSize))

        var analysisRecord = DatabaseRecords.Analysis(
            recordingId: -1,
            pitchEstimationAlgorithm: metadata.pitchEstimationAlgorithm.flatMap { $0.databaseRecord },
            formantEstimationAlgorithm: metadata.formantEstimationAlgorithm.flatMap { $0.databaseRecord },
            lowerLimitLine: metadata.lowerLimitLine,
            upperLimitLine: metadata.upperLimitLine
        )

        let waveHeader = WaveHeader(
            dataLength: UInt32(recordingFileSize) - UInt32(Self.HEADER_LENGTH),
            dataFormat: .IEEEFloat,
            channelCount: 1,
            sampleRate: UInt32(sampleRate),
            bytesPerSample: 4)

        do {
            recordingFile.handle.seek(toFileOffset: 0)
            try recordingFile.handle.write(contentsOf: waveHeader.encode())
        } catch let error {
            os_log("error writing WAVE header to recording file \(error.localizedDescription)")
        }

        do {
            try FileManager.default.moveItem(at: liveRecordingFileUrl, to: destRecordingFileUrl)
        } catch let error {
            os_log("error moving recording file \(error.localizedDescription)")
        }

        try env.databaseStorage.writer().write { [databaseFrames] db in
            try recordingRecord.insert(db)
            analysisRecord.recordingId = recordingRecord.unwrappedId
            try analysisRecord.insert(db)
            for var analysisFrameRecord in databaseFrames {
                analysisFrameRecord.analysisId = analysisRecord.unwrappedId
                try analysisFrameRecord.insert(db)
            }
        }
        os_log("saved recording file \(destRecordingFileUrl.relativeString)")
    }

    func open() {
        dispatchPrecondition(condition: .notOnQueue(dispatchQueue))

        dispatchQueue.sync {
            openOnCurrentThread()
        }
    }

    private func openOnCurrentThread() {
        dispatchPrecondition(condition: .onQueue(dispatchQueue))

        if recordingFile != nil { return }
        do {
            let recordingFileUrl = try AppFilesystem.appLiveRecordingFile()
            FileManager.default.createFile(atPath: recordingFileUrl.path, contents: nil)
            let recordingFile = RecordingFileState(handle: try FileHandle(forWritingTo: recordingFileUrl))
            try recordingFile.handle.truncate(atOffset: 0)
            try recordingFile.handle.write(contentsOf: Data(count: Int(Self.HEADER_LENGTH)))
            self.recordingFile = recordingFile
        } catch let error {
            os_log("error opening live recording file \(error.localizedDescription)")
        }
    }

    func writeData(data: [Float], sampleRate: Double) {
        dispatchPrecondition(condition: .notOnQueue(dispatchQueue))

        dispatchQueue.sync {
            guard let recordingFile = recordingFile else { return }

            var sampleRateChanged = false
            if sampleRate != recordingFile.sampleRate {
                if let oldSampleRate = recordingFile.sampleRate {
                    sampleRateChanged = true
                    os_log("sample rate for recording changed from \(oldSampleRate) to \(sampleRate)")
                }
                self.recordingFile?.sampleRate = sampleRate
            }

            if sampleRateChanged {
                do {
                    try recordingFile.handle.truncate(atOffset: UInt64(Self.HEADER_LENGTH))
                    self.recordingFile?.samples = 0
                } catch let error {
                    os_log("error truncating live recording file: \(error.localizedDescription)")
                }
            }

            do {
                try data.withUnsafeBytes { buffer in
                    try recordingFile.handle.write(contentsOf: Data(buffer))
                }
                self.recordingFile?.samples += UInt64(data.count)
            } catch let error {
                os_log("error writing to live recording file: \(error.localizedDescription)")
            }
        }
    }

    func appendFrame(output: AnalyzerOutput) {
        dispatchPrecondition(condition: .notOnQueue(dispatchQueue))

        dispatchQueue.sync {
            guard let recordingFile = recordingFile else { return }
            guard let sampleRate = recordingFile.sampleRate else { return }
            guard let firstPitch = Array(output.pitches.prefix(1)).first else { return }

            let timeInSeconds = Float(recordingFile.samples) / Float(sampleRate)

            let frame = AnalysisFrame(
                time: timeInSeconds + Float(firstPitch.time),
                pitchFrequency: firstPitch.value,
                pitchConfidence: firstPitch.confidence,
                firstFormantFrequency: nonZeroFloat(output.formants.0.frequency),
                secondFormantFrequency: nonZeroFloat(output.formants.1.frequency)
            )

            let tentativeFrames = output.pitches.dropFirst().compactMap { pitch in
                AnalysisFrame(
                    time: timeInSeconds + Float(pitch.time),
                    pitchFrequency: pitch.value,
                    pitchConfidence: pitch.confidence,
                    firstFormantFrequency: nil,
                    secondFormantFrequency: nil
                )
            }

            databaseFrames.append(frame.databaseRecord)
            frames.send(.append(.init(frame: frame, tentativeFrames: tentativeFrames)))
        }
    }

    func clear() {
        dispatchPrecondition(condition: .notOnQueue(dispatchQueue))

        dispatchQueue.sync {
            clearOnCurrentThread()
        }
    }

    private func clearOnCurrentThread() {
        dispatchPrecondition(condition: .onQueue(dispatchQueue))

        frames.send(.clear)
        databaseFrames = []
        recordingFile = nil
        openOnCurrentThread()
    }
}

private func nonZeroFloat(_ value: Float) -> Float? {
    value.isZero ? nil : value
}

extension PitchEstimationAlgorithm {
    var databaseRecord: DatabaseRecords.PitchEstimationAlgorithm? {
        switch self {
        case .Irapt: return .Irapt
        case .Yin: return .Yin
        default: return nil
        }
    }
}

extension FormantEstimationAlgorithm {
    var databaseRecord: DatabaseRecords.FormantEstimationAlgorithm? {
        switch self {
        case .LibFormants: return .LibFormants
        default: return nil
        }
    }
}
