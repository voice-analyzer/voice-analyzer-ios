import SwiftUI
import Charts

struct PitchChartLimitLines: Equatable {
    let lower: Double?
    let upper: Double?
}

struct PitchChart: UIViewRepresentable {
    typealias UIViewType = LineChartView

    @Binding var highlightedFrameIndex: UInt?
    @Binding var limitLines: PitchChartLimitLines
    let editingLimitLines: Bool

    private static let LINE_WIDTH = 3.0

    private static let MINIMUM_PITCH = 55.0
    private static let MAXIMUM_PITCH = 1760.0

    private let pitchData: [ChartDataEntry]
    private let formantsData: [[ChartDataEntry]]

    init(
        analysisFrames: [AnalysisFrame],
        highlightedFrameIndex: Binding<UInt?>,
        limitLines: Binding<PitchChartLimitLines>,
        editingLimitLines: Bool
    ) {
        _highlightedFrameIndex = highlightedFrameIndex
        _limitLines = limitLines
        self.editingLimitLines = editingLimitLines

        let voicedFrames: [AnalysisFrame] = analysisFrames
            .filter { frame in frame.pitchFrequency > Float(Self.MINIMUM_PITCH) && frame.pitchFrequency < Float(Self.MAXIMUM_PITCH) }

        pitchData = voicedFrames
            .enumerated()
            .map { index, frame in ChartDataEntry(x: Double(index), y: MusicalPitch(fromHz: Double(frame.pitchFrequency)).value) }

        var formantsData: [[ChartDataEntry]] = []
        for (frameIndex, frame) in voicedFrames.enumerated() {
            let frameFormants = frame.formantFrequencies
            if frameFormants.count > formantsData.count {
                formantsData.append(contentsOf: Array(repeating: [], count: frameFormants.count - formantsData.count))
            }
            for (formantIndex, formant) in frameFormants.enumerated() {
                if formant > Float(Self.MINIMUM_PITCH) && formant < Float(Self.MAXIMUM_PITCH) {
                    formantsData[formantIndex]
                        .append(ChartDataEntry(x: Double(frameIndex), y: (Double(MusicalPitch(fromHz: Double(formant)).value))))
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
        chart.leftAxis.axisMinimum = MusicalPitch(fromHz: Self.MINIMUM_PITCH).value
        chart.leftAxis.axisMaximum = MusicalPitch(fromHz: Self.MAXIMUM_PITCH).value
        chart.leftAxis.drawLimitLinesBehindDataEnabled = true
        chart.leftAxis.labelCount = 8
        chart.rightAxis.enabled = false
        chart.delegate = context.coordinator

        updateDataSet(chart: chart)
        return chart
    }

    func updateUIView(_ chart: UIViewType, context: Context) {
        updateDataSet(chart: chart)
        updateLimitLines(chart: chart)
        updateHighlight(chart: chart)
        chart.notifyDataSetChanged()
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

    func updateLimitLines(chart: UIViewType) {
        if let lowerLimitLine = limitLines.lower {
            let lowerLimitLinePitch = MusicalPitch(fromHz: lowerLimitLine)
            chart.leftAxis.addLimitLine(ChartLimitLine(
                limit: lowerLimitLinePitch.value,
                label: lowerLimitLinePitch.closestNote().description()
            ))
        }

        if let upperLimitLine = limitLines.upper {
            let upperLimitLinePitch = MusicalPitch(fromHz: upperLimitLine)
            chart.leftAxis.addLimitLine(ChartLimitLine(
                limit: upperLimitLinePitch.value,
                label: upperLimitLinePitch.closestNote().description()
            ))
        }

        if editingLimitLines {
            chart.isUserInteractionEnabled = false
        } else {
            chart.isUserInteractionEnabled = true
        }
    }

    func updateHighlight(chart: UIViewType) {
        if let highlightedFrameIndex = highlightedFrameIndex {
            chart.highlightValue(x: Double(highlightedFrameIndex), dataSetIndex: 0, callDelegate: false)
        } else {
            chart.highlightValue(nil)
        }
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
    func stringForValue(_ value: Double, axis: AxisBase?) -> String {
        let musicalPitch = MusicalPitch(value: value)
        let noteDescription = musicalPitch.closestNote().description()
        let intHzValue = Int(musicalPitch.hz())
        return "~\(noteDescription) (\(intHzValue)Hz)"
    }
}
