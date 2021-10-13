import SwiftUI
import Charts

struct PitchChart: UIViewRepresentable {
    typealias UIViewType = LineChartView

    @Binding var highlightedFrameIndex: UInt?

    static let PITCH_A0 = 27.5
    static let PITCH_C3 = 130.8
    static let PITCH_C4 = 261.6

    private static let LINE_WIDTH = 3.0

    private static let MINIMUM_PITCH = 55.0
    private static let MAXIMUM_PITCH = 1760.0

    private let pitchData: [ChartDataEntry]
    private let formantsData: [[ChartDataEntry]]

    init(analysisFrames: [AnalysisFrame], highlightedFrameIndex: Binding<UInt?>) {
        _highlightedFrameIndex = highlightedFrameIndex

        let voicedFrames: [AnalysisFrame] = analysisFrames
            .filter { frame in frame.pitchFrequency > Float(Self.MINIMUM_PITCH) && frame.pitchFrequency < Float(Self.MAXIMUM_PITCH) }

        pitchData = voicedFrames
            .enumerated()
            .map { index, frame in ChartDataEntry(x: Double(index), y: Self.convertHzToKey(Double(frame.pitchFrequency))) }

        var formantsData: [[ChartDataEntry]] = []
        for (frameIndex, frame) in voicedFrames.enumerated() {
            let frameFormants = frame.formantFrequencies
            if frameFormants.count > formantsData.count {
                formantsData.append(contentsOf: Array(repeating: [], count: frameFormants.count - formantsData.count))
            }
            for (formantIndex, formant) in frameFormants.enumerated() {
                if formant > Float(Self.MINIMUM_PITCH) && formant < Float(Self.MAXIMUM_PITCH) {
                    formantsData[formantIndex]
                        .append(ChartDataEntry(x: Double(frameIndex), y: Self.convertHzToKey(Double(formant))))
                }
            }
        }
        self.formantsData = formantsData
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
        chart.leftAxis.labelCount = 8
        chart.rightAxis.enabled = false
        chart.delegate = context.coordinator

        updateDataSet(chart: chart)
        return chart
    }

    func updateUIView(_ chart: UIViewType, context: Context) {
        updateDataSet(chart: chart)
        if let highlightedFrameIndex = highlightedFrameIndex {
            chart.highlightValue(x: Double(highlightedFrameIndex), dataSetIndex: 0, callDelegate: false)
        } else {
            chart.highlightValue(nil)
        }
        chart.notifyDataSetChanged()
    }

    static func convertHzToKey(_ hz: Double) -> Double {
        log2(hz / Self.PITCH_A0)
    }

    func updateDataSet(chart: UIViewType) {
        var dataSets: [LineChartDataSet] = []
        if !pitchData.isEmpty {
            let pitchDataSet = LineChartDataSet(entries: pitchData)
            pitchDataSet.drawCirclesEnabled = false
            pitchDataSet.drawValuesEnabled = false
            pitchDataSet.drawIconsEnabled = false
            pitchDataSet.lineWidth = Self.LINE_WIDTH
            pitchDataSet.setColor(UIColor(Color.accentColor))
            pitchDataSet.mode = .horizontalBezier
            dataSets.append(pitchDataSet)
        }

        for formantData in formantsData {
            let formantDataSet = LineChartDataSet(entries: formantData)
            formantDataSet.drawCirclesEnabled = false
            formantDataSet.drawValuesEnabled = false
            formantDataSet.drawIconsEnabled = false
            formantDataSet.mode = .horizontalBezier
            formantDataSet.lineWidth = Self.LINE_WIDTH
            formantDataSet.setColor(.systemYellow)
            dataSets.append(formantDataSet)
        }

        if dataSets.isEmpty {
            let dummyDataEntries = [ChartDataEntry(x: 1, y: 0)]
            let dummyDataSet = LineChartDataSet(entries: dummyDataEntries)
            dummyDataSet.visible = false
            dataSets.append(dummyDataSet)
        }

        chart.data = LineChartData(dataSets: dataSets)
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }

    class Coordinator: NSObject, ChartViewDelegate {
        let chart: PitchChart

        init(_ chart: PitchChart) {
            self.chart = chart
        }

        func chartValueSelected(_ chartView: ChartViewBase, entry: ChartDataEntry, highlight: Highlight) {
            chart.highlightedFrameIndex = UInt(entry.x)
        }
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
