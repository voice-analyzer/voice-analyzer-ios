import SwiftUI
import Charts
import VoiceAnalyzerRust

struct ChartView: View {
    @Binding var analysisFrames: [AnalyzerOutput]

    var body: some View {
        PitchChart(analysisFrames: analysisFrames)
    }
}
