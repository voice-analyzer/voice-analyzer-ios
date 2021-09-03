import SwiftUI
import Charts

struct ChartView: View {
    @Binding var analysisFrames: [AnalyzerOutput]

    var body: some View {
        PitchChart(analysisFrames: analysisFrames)
    }
}
