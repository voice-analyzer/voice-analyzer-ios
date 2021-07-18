import SwiftUI
import Charts
import VoiceAnalyzerRust

struct ChartView: View {
    @Binding var pitches: [Pitch]

    var body: some View {
        BarChart(data: pitches.enumerated().map { BarChartDataEntry(x: Double($0), y: Double($1.value)) })
    }
}
