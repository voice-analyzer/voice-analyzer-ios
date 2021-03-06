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
    @State private var expandedRecordingId: Int64?
    @State private var pitchChartActive: Bool = false
    @State private var shareSheetPresented: Bool = false
    @State private var shareSheetActivityItems: [Any] = []

    var body: some View {
        Group {
            recordingsList
            activityView
        }
    }
    var recordingsList: some View {
        List(selection: $selectedRecordingIndices) {
            ForEach(Array(recordings.enumerated()), id: \.1.unwrappedId) { (index, recording) in
                let expanded: RecordingRow.ExpansionState =
                    recording.id == expandedRecordingId
                    ? .expanded(RecordingRow.ExpandedState(pitchChartActive: $pitchChartActive)) : .collapsed
                RecordingRow(
                    recording: recording,
                    expanded: expanded,
                    playback: playback,
                    shareSheetActivityItems: $shareSheetActivityItems,
                    shareSheetPresented: $shareSheetPresented
                )
                .tag(index)
                .contentShape(Rectangle())
                .onTapGesture {
                    if case .collapsed = expanded {
                        switch editMode?.wrappedValue {
                        case .some(.inactive), .none:
                            expandedRecordingId = recording.id
                        default: break
                        }
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
            if !pitchChartActive {
                playback.pausePlayback(env: env)
            }
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
        .onChange(of: expandedRecordingId) { [expandedRecordingId] newExpandedRecordingId in
            if newExpandedRecordingId != expandedRecordingId {
                playback.stopPlayback(env: env)
                playback.currentTime = 0
            }
        }
    }

    private var activityView: some View {
        ActivityView(
            activityItems: shareSheetActivityItems,
            applicationActivities: [
                Activity(title: "View Recording Details", image: UIImage(systemName: "waveform")) {
                    shareSheetPresented = false
                    pitchChartActive = true
                },
                Activity(title: "Delete", image: UIImage(systemName: "trash")) {
                    shareSheetPresented = false
                    if let expandedRecordingId = expandedRecordingId {
                        deleteRecording(id: expandedRecordingId)
                    }
                },
            ],
            isPresented: $shareSheetPresented
        )
        .frame(width: 0, height: 0)
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

    private func deleteRecording(id: Int64) {
        if let recording = recordings.first(where: { recording in recording.id == id }) {
            deleteRecordings(recordings: AnyCollection([recording]))
        }
    }

    private func deleteRecordings<C: Collection>(at indices: C) where C.Element: BinaryInteger {
        let recordings = indices.lazy.map { index in self.recordings[Int(index)] }
        deleteRecordings(recordings: AnyCollection(recordings))
    }

    private func deleteRecordings(recordings: AnyCollection<DatabaseRecords.Recording>) {
        let ids = Array(recordings.compactMap { recording in recording.id })
        let filenames = Array(recordings.compactMap { recording in recording.filename })
        if let expandedRecordingId = expandedRecordingId, ids.contains(where: { $0 == expandedRecordingId }) {
            self.expandedRecordingId = nil
        }
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
                os_log("deleted \(deleteCount) recordings")
            case .failure(let error):
                os_log("error deleting recordings from database: \(error.localizedDescription)")
            }
        }
    }
    private func deleteRecordingFiles(filenames: [String]) {
        for filename in filenames {
            do {
                let url = try AppFilesystem.appRecordingDirectory().appendingPathComponent(filename)
                try FileManager.default.removeItem(at: url)
            } catch let error {
                os_log("error deleting recording file: \(error.localizedDescription)")
            }
        }
    }

    private static func queryAllRecordings(db: Database) throws -> [DatabaseRecords.Recording] {
        try DatabaseRecords.Recording.order(DatabaseRecords.Recording.Columns.timestamp.desc).fetchAll(db)
    }
}

private struct RecordingRow: View {
    enum ExpansionState {
        case collapsed
        case expanded(ExpandedState)
    }

    struct ExpandedState {
        @Binding var pitchChartActive: Bool
    }

    let recording: DatabaseRecords.Recording
    let expanded: ExpansionState
    @ObservedObject var playback: VoicePlaybackModel
    @Binding var shareSheetActivityItems: [Any]
    @Binding var shareSheetPresented: Bool

    @Environment(\.env) private var env: AppEnvironment
    @Environment(\.editMode) private var editMode: Binding<EditMode>?
    @State private var sliderPausedPlayback: Bool = false
    @State private var name: String
    private let initialName: String
    private let url: URL?

    private var seekAmount: UInt {
        switch UInt(recording.length) {
        case 00...30:
            if #available(iOS 15, *) {
                return 5
            } else {
                return 10
            }
        case 30...60: return 10
        default: return 15
        }
    }

    private var isExpanded: Bool {
        if case .expanded(_) = expanded { return true } else { return false }
    }

    init(
        recording: DatabaseRecords.Recording,
        expanded: ExpansionState,
        playback: VoicePlaybackModel,
        shareSheetActivityItems: Binding<[Any]>,
        shareSheetPresented: Binding<Bool>
    ) {
        self.recording = recording
        self.expanded = expanded
        self.playback = playback
        if let filename = recording.filename {
            do {
                url = try AppFilesystem.appRecordingDirectory().appendingPathComponent(filename)
            } catch let error {
                os_log("error calculating path for recording file: \(error.localizedDescription)")
                url = nil
            }
        } else {
            url = nil
        }
        initialName = recording.name ?? "Untitled Recording"
        _name = State(initialValue: initialName)
        _shareSheetActivityItems = shareSheetActivityItems
        _shareSheetPresented = shareSheetPresented
    }

    var formattedRecordingFileSize: String? {
        guard let byteCount = recording.fileSize else { return nil }
        let size = Measurement(value: Double(byteCount), unit: UnitInformationStorage.bytes)
        let convertedSize = size.converted(to: .megabytes)
        return String.localizedStringWithFormat("%0.2f %@", convertedSize.value, convertedSize.unit.symbol)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                TextField(initialName, text: $name) { _ in
                } onCommit: {
                    if !name.isEmpty && name != initialName {
                        commitName()
                    } else {
                        name = initialName
                    }
                }
                .font(.headline)
                .disabled(!isExpanded)
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

            if case .expanded(let expandedState) = expanded {
                NavigationLink(
                    destination: RecordingPitchChart(recording: recording, playback: playback),
                    isActive: expandedState.$pitchChartActive
                ) {
                    EmptyView()
                }
                .hidden()

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
        VoicePlaybackSlider(playback: playback, pausedPlayback: $sliderPausedPlayback, recordingLength: Float(recording.length))
    }

    var buttonsRow: some View {
        ZStack(alignment: .center) {
            HStack {
                shareButton
                Spacer()
            }
            mediaButtons
            HStack {
                Spacer()
                viewDetailsButton
            }
        }
        .buttonStyle(PlainButtonStyle())
        .font(.system(size: 24))
    }

    var shareButton: some View {
        Button {
            if let url = url {
                shareSheetActivityItems = [url]
                shareSheetPresented = true
            }
        } label: {
            Image(systemName: "ellipsis")
                .foregroundColor(.accentColor)
        }
        .disabled(url == nil)
        .imageScale(.medium)
    }

    var mediaButtons: some View {
        HStack(spacing: 40) {
            Button {
                seek(by: -Float(seekAmount))
            } label: {
                Image(systemName: "gobackward.\(seekAmount)")
            }
            .imageScale(.medium)
            Button {
                guard let filename = recording.filename else { return }
                do {
                    try playback.togglePlayback(env: env, filename: filename)
                } catch let error {
                    os_log("error playing file \(filename): \(error.localizedDescription)")
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
            Button {
                seek(by: Float(seekAmount))
            } label: {
                Image(systemName: "goforward.\(seekAmount)")
            }
            .imageScale(.medium)
        }
    }

    var viewDetailsButton: some View {
        Button {
            if case .expanded(let expandedState) = expanded {
                expandedState.pitchChartActive = true
            }
        } label: {
            Image(systemName: "waveform")
                .foregroundColor(.accentColor)
        }
        .imageScale(.medium)
    }

    func seek(by seconds: Float) {
        let seekTime = (playback.currentTime + seconds).clamped(0...Float(recording.length))
        if seekTime < Float(recording.length) - 0.25 {
            playback.currentTime = seekTime
        }
    }

    func commitName() {
        var newRecording = recording
        newRecording.name = name
        env.databaseStorage.writer().asyncWrite { db in
            try newRecording.update(db)
        } completion: { db, result in
            switch result {
            case .success(_):
                os_log("updated recording name")
            case .failure(let error):
                os_log("error updating recording name in database: \(error.localizedDescription)")
            }
        }
    }
}
