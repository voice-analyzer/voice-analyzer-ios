import SwiftUI
import Charts

struct ChartView: View {
    let analysisFrames: [AnalysisFrame]

    var body: some View {
        PitchChart(analysisFrames: analysisFrames)
    }
}
