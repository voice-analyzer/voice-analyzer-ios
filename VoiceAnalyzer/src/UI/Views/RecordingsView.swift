import Foundation
import GRDB
import SwiftUI
import os

struct RecordingsView: View {
    @Environment(\.env) private var env: AppEnvironment
    @Environment(\.editMode) private var editMode: Binding<EditMode>?
    @StateObject private var playback = VoicePlaybackModel()
    @DatabaseQuery(Self.queryAllRecordings) private var recordings: [DatabaseRecords.Recording] = []
    @State private var selectedRecordingIndices: Set<Int> = Set()
    @State private var expandedRecordingIndex: Int?

    var body: some View {
        List(selection: $selectedRecordingIndices) {
            ForEach(Array(recordings.enumerated()), id: \.1.unwrappedId) { (index, recording) in
                let expanded = index == expandedRecordingIndex
                RecordingRow(recording: recording, expanded: expanded, playback: playback)
                    .tag(index)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if !expanded, editMode?.wrappedValue != .active {
                            expandedRecordingIndex = index
                        }
                    }
            }
            .onDelete { indices in
                deleteRecordings(at: indices)
            }
        }
        .listStyle(PlainListStyle())
        .navigationBarTitle("Recordings")
        .onDisappear {
            editMode?.wrappedValue = .inactive
            expandedRecordingIndex = nil
        }
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                if editMode?.wrappedValue == .active {
                    Spacer()
                    editingDeleteButton
                }
            }
            ToolbarItem(placement: .primaryAction) {
                if !recordings.isEmpty {
                    EditButton()
                }
            }
        }
        .onChange(of: editMode?.wrappedValue) { newEditMode in
            if case .active = newEditMode {
                playback.pausePlayback(env: env)
            }
        }
        .onChange(of: expandedRecordingIndex) { [expandedRecordingIndex] newExpandedRecordingIndex in
            if newExpandedRecordingIndex != expandedRecordingIndex {
                playback.stopPlayback(env: env)
            }
        }
    }

    private var editingDeleteButton: some View {
        Button {
            deleteRecordings(at: selectedRecordingIndices)
            selectedRecordingIndices = Set()
            editMode?.wrappedValue = .inactive
        } label: {
            Text("Delete")
        }
        .environment(\.isEnabled, !selectedRecordingIndices.isEmpty)
    }

    private func deleteRecordings<C: Collection>(at indices: C) where C.Element: BinaryInteger {
        if let expandedRecordingIndex = expandedRecordingIndex, indices.contains(where: { $0 == expandedRecordingIndex }) {
            self.expandedRecordingIndex = nil
        }
        let recordings = indices.lazy.map { index in self.recordings[Int(index)] }
        deleteRecordings(recordings: AnyCollection(recordings))
    }

    private func deleteRecordings(recordings: AnyCollection<DatabaseRecords.Recording>) {
        let ids = Array(recordings.compactMap { recording in recording.id })
        let filenames = Array(recordings.compactMap { recording in recording.filename })
        env.databaseStorage.writer().asyncWrite { db -> Int in
            let deleted = try DatabaseRecords.Recording.deleteAll(db, keys: ids)
            try DatabaseRecords.Analysis
                .filter(ids.contains(DatabaseRecords.Analysis.Columns.recordingId))
                .select(DatabaseRecords.Analysis.Columns.id, as: Int64.self)
                .fetchCursor(db)
                .forEach { analysisId in
                    try DatabaseRecords.Analysis.deleteOne(db, key: analysisId)
                    try DatabaseRecords.AnalysisFrame
                        .filter(DatabaseRecords.AnalysisFrame.Columns.analysisId == analysisId)
                        .deleteAll(db)
                }
            return deleted
        } completion: { db, result in
            switch result {
            case .success(let deleteCount):
                deleteRecordingFiles(filenames: filenames)
                os_log("deleted %d recordings", deleteCount)
            case .failure(let error):
                os_log("error deleting recordings from database: %@", error.localizedDescription)
            }
        }
    }
    private func deleteRecordingFiles(filenames: [String]) {
        for filename in filenames {
            do {
                let url = try AppFilesystem.appRecordingDirectory().appendingPathComponent(filename)
                try FileManager.default.removeItem(at: url)
            } catch {
                os_log("error deleting recording file: %@", error.localizedDescription)
            }
        }
    }

    private static func queryAllRecordings(db: Database) throws -> [DatabaseRecords.Recording] {
        try DatabaseRecords.Recording.order(DatabaseRecords.Recording.Columns.timestamp.desc).fetchAll(db)
    }
}

private struct RecordingRow: View {
    let recording: DatabaseRecords.Recording
    let expanded: Bool
    @ObservedObject var playback: VoicePlaybackModel

    @Environment(\.env) private var env: AppEnvironment
    @Environment(\.editMode) private var editMode: Binding<EditMode>?
    @State private var sliderPausedPlayback: Bool = false
    @State private var pitchChartActive: Bool = false

    var formattedRecordingFileSize: String? {
        guard let byteCount = recording.fileSize else { return nil }
        let size = Measurement(value: Double(byteCount), unit: UnitInformationStorage.bytes)
        let convertedSize = size.converted(to: .megabytes)
        return String.localizedStringWithFormat("%0.2f %@", convertedSize.value, convertedSize.unit.symbol)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(recording.name ?? "Untitled Recording")
                    .font(.headline)
                if editMode?.wrappedValue == .active {
                    if let formattedRecordingFileSize = formattedRecordingFileSize {
                        Spacer()
                        Text(formattedRecordingFileSize)
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                    }
                }
            }
            HStack {
                Text(DateFormatter.localizedString(from: recording.timestamp, dateStyle: .medium, timeStyle: .none))
                Spacer()
                Text(DateFormatter.localizedString(from: recording.timestamp, dateStyle: .none, timeStyle: .short))
            }
            .foregroundColor(.secondary)
            .font(.subheadline)

            NavigationLink(destination: RecordingPitchChart(recordingId: recording.unwrappedId), isActive: $pitchChartActive) {
                EmptyView()
            }
            .hidden()

            if expanded {
                expandedBody
                    .transition(
                        .asymmetric(
                            insertion: .opacity.animation(.default),
                            removal: .opacity
                        )
                    )
            }
        }
        .padding(.vertical, 5)
    }

    var expandedBody: some View {
        VStack(spacing: 25) {
            seekSlider
            buttonsRow
        }
        .padding(.top, 25)
        .padding(.bottom, 10)
    }

    var seekSlider: some View {
        VStack(spacing: 0) {
            RecordingRowSlider(playback: playback, pausedPlayback: $sliderPausedPlayback, maximumValue: Float(recording.length))
            HStack {
                Text(formatRecordingLength(playback.currentTime))
                Spacer()
                Text(formatRecordingLength(playback.currentTime - Float(recording.length)))
            }
            .foregroundColor(.secondary)
            .font(.caption)
        }
    }

    var buttonsRow: some View {
        ZStack(alignment: .center) {
            mediaButtons
            HStack {
                Spacer()
                viewDetailsButton
            }
        }
        .buttonStyle(PlainButtonStyle())
        .font(.system(size: 24))
    }

    var mediaButtons: some View {
        HStack(spacing: 40) {
            Button { seek(by: -15) } label: {
                Image(systemName: "gobackward.15")
            }
            .imageScale(.medium)
            Button {
                guard let filename = recording.filename else { return }
                do {
                    try playback.togglePlayback(env: env, filename: filename)
                } catch {
                    os_log("error playing file %@: %@", filename, error.localizedDescription)
                }
            } label: {
                ZStack {
                    if !playback.isPlaying && !sliderPausedPlayback {
                        Image(systemName: "play.fill")
                        Image(systemName: "pause.fill").hidden()
                    } else {
                        Image(systemName: "pause.fill")
                        Image(systemName: "play.fill").hidden()
                    }
                }
            }
            .imageScale(.large)
            Button { seek(by: 15) } label: {
                Image(systemName: "goforward.15")
            }
            .imageScale(.medium)
        }
    }

    var viewDetailsButton: some View {
        Button {
            pitchChartActive = true
        } label: {
            Image(systemName: "waveform")
        }
        .imageScale(.medium)
    }

    func seek(by seconds: Float) {
        let seekTime = (playback.currentTime + seconds).clamped(0...Float(recording.length))
        if seekTime < Float(recording.length) - 0.25 {
            playback.currentTime = seekTime
        }
    }
}

private func formatRecordingLength(_ length: Float) -> String {
    let interval = TimeInterval(length)
    let formatter = DateComponentsFormatter()
    formatter.unitsStyle = .positional
    if interval >= 60 * 60 {
        formatter.allowedUnits = [.hour, .minute, .second]
    } else {
        formatter.allowedUnits = [.minute, .second]
    }
    formatter.zeroFormattingBehavior = .pad
    formatter.maximumUnitCount = 2
    if let formatted = formatter.string(from: interval) {
        if length.sign == .minus {
            return "-\(formatted)"
        } else {
            return formatted
        }
    } else {
        return "??:??"
    }
}

struct RecordingRowSlider: UIViewRepresentable {
    @ObservedObject var playback: VoicePlaybackModel
    @Binding var pausedPlayback: Bool
    var maximumValue: Float

    @Environment(\.env) private var env: AppEnvironment

    func makeUIView(context: Context) -> UISlider {
        let slider = UISlider()
        slider.maximumValue = maximumValue

        slider.minimumTrackTintColor = UIColor.systemGray
        slider.maximumTrackTintColor = UIColor.secondarySystemFill

        let thumbImageConfiguration = UIImage.SymbolConfiguration(scale: .small)
        let thumbImage = UIImage(systemName: "circle.fill", withConfiguration: thumbImageConfiguration)!
            .withTintColor(slider.minimumTrackTintColor!, renderingMode: .alwaysOriginal)
        slider.setThumbImage(thumbImage, for: .disabled)
        slider.setThumbImage(thumbImage, for: .normal)
        slider.setThumbImage(thumbImage, for: .selected)
        slider.setThumbImage(thumbImage, for: .highlighted)

        slider.addTarget(context.coordinator, action: #selector(Coordinator.updateValue(slider:)), for: .valueChanged)
        slider.addTarget(context.coordinator, action: #selector(Coordinator.sliderTouchDown(slider:)), for: .touchDown)
        slider.addTarget(context.coordinator, action: #selector(Coordinator.sliderTouchUp(slider:)), for: .touchUpInside)
        slider.addTarget(context.coordinator, action: #selector(Coordinator.sliderTouchUp(slider:)), for: .touchUpOutside)

        return slider
    }

    func updateUIView(_ slider: UISlider, context: Context) {
        slider.setValue(playback.currentTime, animated: true)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject {
        let slider: RecordingRowSlider

        init(_ slider: RecordingRowSlider) {
            self.slider = slider
        }

        @objc func updateValue(slider: UISlider) {
            self.slider.playback.currentTime = slider.value
        }

        @objc func sliderTouchDown(slider: UISlider) {
            if self.slider.playback.isPlaying {
                self.slider.playback.pausePlayback(env: self.slider.env)
                self.slider.pausedPlayback = true
            }
        }

        @objc func sliderTouchUp(slider: UISlider) {
            if self.slider.pausedPlayback {
                self.slider.pausedPlayback = false
                do {
                    try self.slider.playback.resumePlayback(env: self.slider.env)
                } catch {
                    os_log("error resuming playback: %@", error.localizedDescription)
                }
            }
        }
    }
}
