import SwiftUI
import Charts

struct ChartView: View {
    @Binding var barEntries: [BarChartDataEntry]

    var body: some View {
        BarChart(data: $barEntries)
    }
}
