import SwiftUI
import Charts

@main
struct VoiceAnalyzerApp: App {
    @State var barEntries: [BarChartDataEntry] = []

    var body: some Scene {
        WindowGroup {
            VStack {
                ChartView(barEntries: $barEntries)
                Button(action: {
                    barEntries.append(BarChartDataEntry(x: Double(barEntries.count), y: Double(barEntries.count)))
                }) {
                    Text("Add Bar")
                        .padding(.all, 5)
                        .border(Color.black)
                }
            }
        }
    }
}
