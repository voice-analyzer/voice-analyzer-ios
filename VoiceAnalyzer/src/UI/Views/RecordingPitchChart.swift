import os
import Foundation
import GRDB
import SwiftUI

struct RecordingPitchChart: View {
    var recordingId: Int64
    var analysisId: Int64?

    @ObservedObject var playback: VoicePlaybackModel
    @State var highlightedFrameIndex: UInt?
    @State var sliderPausedPlayback: Bool = false
    @State var limitLines: PitchChartLimitLines = PitchChartLimitLines(lower: nil, upper: nil)

    struct Analysis {
        var analysis: DatabaseRecords.Analysis
        var frames: [DatabaseRecords.AnalysisFrame]
    }

    @Environment(\.env) private var env: AppEnvironment
    @DatabaseQuery private var recording: DatabaseRecords.Recording?
    @DatabaseQuery private var analysis: Analysis?

    init(recording: DatabaseRecords.Recording, playback: VoicePlaybackModel) {
        let recordingId = recording.unwrappedId
        self.recordingId = recordingId
        self.playback = playback

        _recording = DatabaseQuery(wrappedValue: recording) { db in try Self.queryRecording(db: db, recordingId: recordingId) }
        _analysis = DatabaseQuery(wrappedValue: nil) { db in try Self.queryAnalysis(db: db, recordingId: recordingId) }
    }

    var navigationBarTitle: String {
        if let recording = recording {
            return recording.name ?? "Untitled Recording"
        } else {
            return ""
        }
    }

    var body: some View {
        GeometryReader {
            geometry in
            VStack(spacing: 0) {
                chartView
                playbackSliderView
                Divider()
                ZStack {
                    toolbarView
                }
                .frame(height: 44 + geometry.safeAreaInsets.bottom, alignment: .top)
                .background(Color(UIColor.secondarySystemBackground))
            }
            .ignoresSafeArea(.all, edges: .bottom)
            .navigationBarTitle(navigationBarTitle)
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: playback.currentTime) { currentTime in updateHighlightedFrame(currentTime: currentTime) }
            .onChange(of: analysis?.frames.count) { _ in updateHighlightedFrame() }
            .onChange(of: analysis?.analysis) { analysis in
                limitLines = PitchChartLimitLines(lower: analysis?.upperLimitLine, upper: analysis?.lowerLimitLine)
            }
        }
    }

    var chartView: some View {
        ChartView(
            analysisFrames: (analysis?.frames ?? []).compactMap(AnalysisFrame.from),
            tentativeAnalysisFrames: [],
            highlightedFrameIndex: Binding { highlightedFrameIndex } set: {
                highlightedFrameIndex = $0
                if let highlightedFrameIndex = highlightedFrameIndex,
                   let frames = analysis?.frames,
                   highlightedFrameIndex < frames.count
                {
                    playback.pausePlayback(env: env)
                    playback.currentTime = frames[Int(highlightedFrameIndex)].time
                }
            },
            limitLines: $limitLines,
            editingLimitLines: false
        )
    }

    var playbackSliderView: some View {
        VoicePlaybackSlider(playback: playback, pausedPlayback: $sliderPausedPlayback, recordingLength: Float(recording?.length ?? 0))
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
    }

    var toolbarView: some View {
        ZStack {
            HStack {
                Spacer()
                mediaButtons
                Spacer()
            }
        }
        .font(.system(size: 18))
        .imageScale(.large)
        .padding(.horizontal, 16)
        .frame(height: 44)
    }

    var mediaButtons: some View {
        HStack(spacing: 40) {
            Button { seek(by: -15) } label: {
                Image(systemName: "gobackward.15")
            }
            playButton
            Button { seek(by: 15) } label: {
                Image(systemName: "goforward.15")
            }
        }
    }

    var playButton: some View {
        Button(action: {
            do {
                if let recordingFilename = recording?.filename {
                    try playback.togglePlayback(env: env, filename: recordingFilename)
                } else if playback.isPlaying {
                    playback.pausePlayback(env: env)
                }
            } catch let error {
                os_log("error toggling recording: \(error.localizedDescription)")
            }
        }) {
            Image(systemName: playback.isPlaying || sliderPausedPlayback ? "pause" : "play")
        }
    }

    private func updateHighlightedFrame() {
        updateHighlightedFrame(currentTime: playback.currentTime)
    }

    private func updateHighlightedFrame(currentTime: Float) {
        guard let currentFrameIndex = analysis?.frames.firstIndex(where: { frame in frame.time > currentTime }) else { return }
        highlightedFrameIndex = UInt(currentFrameIndex)
    }

    private func seek(by seconds: Float) {
        guard let recording = recording else { return }
        let seekTime = (playback.currentTime + seconds).clamped(0...Float(recording.length))
        if seekTime < Float(recording.length) - 0.25 {
            playback.currentTime = seekTime
        }
    }

    private static func queryRecording(db: Database, recordingId: Int64) throws -> DatabaseRecords.Recording? {
        try DatabaseRecords.Recording.fetchOne(db, key: recordingId)
    }

    private static func queryAnalysis(db: Database, recordingId: Int64) throws -> Analysis? {
        guard let analysis = try DatabaseRecords.Analysis.fetchOne(db, key: recordingId) else { return nil }

        let frames = try DatabaseRecords.AnalysisFrame
            .filter(DatabaseRecords.AnalysisFrame.Columns.analysisId == analysis.unwrappedId)
            .fetchAll(db)

        return Analysis(analysis: analysis, frames: frames)
    }
}
