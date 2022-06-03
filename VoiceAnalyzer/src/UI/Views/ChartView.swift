import Charts
import SwiftUI

struct ChartView: View {
    @ObservedObject var analysis: PitchChartAnalysisFrames
    @Binding var highlightedFrameIndex: UInt?
    @Binding var limitLines: PitchChartLimitLines
    let editingLimitLines: Bool

    var body: some View {
        PitchChart(
            analysis: analysis,
            highlightedFrameIndex: $highlightedFrameIndex,
            limitLines: $limitLines,
            editingLimitLines: editingLimitLines
        )
    }
}
