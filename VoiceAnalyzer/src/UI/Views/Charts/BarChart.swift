import SwiftUI
import Charts

struct BarChart: UIViewRepresentable {
    typealias UIViewType = BarChartView

    var data: [BarChartDataEntry]

    func makeUIView(context: Context) -> UIViewType {
        let chart = BarChartView()
        chart.data = BarChartData(dataSet: BarChartDataSet(entries: data))
        return chart
    }

    func updateUIView(_ chart: UIViewType, context: Context) {
        chart.data = BarChartData(dataSet: BarChartDataSet(entries: data))
        chart.notifyDataSetChanged()
    }
}
