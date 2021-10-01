import os
import Foundation
import GRDB
import SwiftUI

struct RecordingPitchChart: View {
    var recordingId: Int64
    var analysisId: Int64?

    struct Analysis {
        var analysis: DatabaseRecords.Analysis
        var frames: [DatabaseRecords.AnalysisFrame]
    }

    @DatabaseQuery private var recording: DatabaseRecords.Recording?
    @DatabaseQuery private var analysis: Analysis?

    init(recordingId: Int64) {
        self.recordingId = recordingId

        _recording = DatabaseQuery(wrappedValue: nil) { db in try Self.queryRecording(db: db, recordingId: recordingId) }
        _analysis = DatabaseQuery(wrappedValue: nil) { db in try Self.queryAnalysis(db: db, recordingId: recordingId) }
    }

    var body: some View {
        chartView
        .navigationBarTitle(recording?.name ?? "Untitled Recording")
        .navigationBarTitleDisplayMode(.inline)
    }

    var chartView: some View {
        ChartView(analysisFrames: (analysis?.frames ?? []).compactMap(AnalysisFrame.from))
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
