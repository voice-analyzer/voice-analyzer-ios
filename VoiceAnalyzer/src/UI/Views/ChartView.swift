import SwiftUI
import Charts

struct ChartView: View {
    let analysisFrames: [AnalysisFrame]
    let tentativeAnalysisFrames: [AnalysisFrame]
    @Binding var highlightedFrameIndex: UInt?
    @Binding var limitLines: PitchChartLimitLines
    let editingLimitLines: Bool

    var body: some View {
        PitchChart(
            analysisFrames: analysisFrames,
            tentativeAnalysisFrames: tentativeAnalysisFrames,
            highlightedFrameIndex: $highlightedFrameIndex,
            limitLines: $limitLines,
            editingLimitLines: editingLimitLines
        )
    }
}
