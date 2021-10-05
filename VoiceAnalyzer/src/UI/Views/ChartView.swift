import SwiftUI
import Charts

struct ChartView: View {
    let analysisFrames: [AnalysisFrame]
    @Binding var highlightedFrameIndex: UInt?

    var body: some View {
        PitchChart(analysisFrames: analysisFrames, highlightedFrameIndex: $highlightedFrameIndex)
    }
}
