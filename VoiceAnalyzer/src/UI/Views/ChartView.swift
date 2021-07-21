import SwiftUI
import Charts
import VoiceAnalyzerRust

struct ChartView: View {
    @Binding var pitches: [Pitch]

    var body: some View {
        PitchChart(pitches: pitches)
    }
}
