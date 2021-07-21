import SwiftUI
import Charts
import VoiceAnalyzerRust

struct PitchChart: UIViewRepresentable {
    typealias UIViewType = LineChartView

    static let PITCH_A0 = 27.5
    static let PITCH_C3 = 130.8
    static let PITCH_C4 = 261.6

    private static let MINIMUM_PITCH = 55.0
    private static let MAXIMUM_PITCH = 880.0

    private let data: [ChartDataEntry]

    init(pitches: [Pitch]) {
        data = pitches
            .filter({ pitch in pitch.value > Float(Self.MINIMUM_PITCH) && pitch.value < Float(Self.MAXIMUM_PITCH) })
            .enumerated()
            .map { ChartDataEntry(x: Double($0), y: Self.convertHzToKey(Double($1.value))) }
    }

    func makeUIView(context: Context) -> UIViewType {
        let chart = UIViewType()
        chart.legend.enabled = false
        chart.xAxis.drawGridLinesEnabled = false
        chart.xAxis.drawLabelsEnabled = false
        chart.leftAxis.valueFormatter = HzValueFormatter()
        chart.leftAxis.axisMinimum = 1.0
        chart.leftAxis.axisMaximum = Self.convertHzToKey(Self.MAXIMUM_PITCH)
        chart.leftAxis.addLimitLine(ChartLimitLine(limit: Self.convertHzToKey(Self.PITCH_C3), label: "C3"))
        chart.leftAxis.addLimitLine(ChartLimitLine(limit: Self.convertHzToKey(Self.PITCH_C4), label: "C4"))
        chart.leftAxis.drawLimitLinesBehindDataEnabled = true
        chart.rightAxis.enabled = false

        updateDataSet(chart: chart)
        return chart
    }

    func updateUIView(_ chart: UIViewType, context: Context) {
        updateDataSet(chart: chart)
        chart.notifyDataSetChanged()
    }

    static func convertHzToKey(_ hz: Double) -> Double {
        log2(hz / Self.PITCH_A0)
    }

    func updateDataSet(chart: UIViewType) {
        let pitchDataSet = LineChartDataSet(entries: data)
        pitchDataSet.drawCirclesEnabled = false
        pitchDataSet.drawValuesEnabled = false
        pitchDataSet.drawIconsEnabled = false

        chart.data = LineChartData(dataSet: pitchDataSet)
    }
}

class HzValueFormatter: IAxisValueFormatter {
    static let NOTES = ["A", "A#", "B", "C", "C#", "D", "D#", "E", "F", "F#", "G", "G#"]
    func stringForValue(_ value: Double, axis: AxisBase?) -> String {
        let note = Self.NOTES[Int(round(12.0 * value)) % 12]
        let octave = 1 + Int(value - 3.0 / 12.0)
        let intHzValue = Int(PitchChart.PITCH_A0 * pow(2.0, value))
        return "~\(note)\(octave) (\(intHzValue)Hz)"
    }
}
