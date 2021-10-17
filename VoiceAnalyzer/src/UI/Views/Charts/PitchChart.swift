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
    private static let MAX_LINE_SEGMENT_JUMP_IN_Y = 0.75

    private static let MINIMUM_PITCH = 55.0
    private static let MAXIMUM_PITCH = 1760.0

    private let pitchDataSegments: [[ChartDataEntry]]
    private let formantsDataSegments: [[[ChartDataEntry]]]

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

        pitchDataSegments = voicedFrames
            .enumerated()
            .lazy
            .map { index, frame in ChartDataEntry(x: Double(index), y: MusicalPitch(fromHz: Double(frame.pitchFrequency)).value) }
            .group { a, b in abs(a.y - b.y) <= Self.MAX_LINE_SEGMENT_JUMP_IN_Y }

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
        formantsDataSegments = formantsData
            .map { formantData in formantData.group { a, b in abs(a.y - b.y) <= Self.MAX_LINE_SEGMENT_JUMP_IN_Y } }
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
        if !pitchDataSegments.isEmpty {
            for pitchDataSegment in pitchDataSegments {
                let pitchDataSet = LineChartDataSet(entries: pitchDataSegment)
                pitchDataSet.drawCirclesEnabled = false
                pitchDataSet.drawValuesEnabled = false
                pitchDataSet.drawIconsEnabled = false
                pitchDataSet.lineWidth = Self.LINE_WIDTH
                pitchDataSet.setColor(UIColor(Color.accentColor))
                pitchDataSet.mode = .horizontalBezier
                dataSets.append(pitchDataSet)
            }
        }

        for formantDataSegments in formantsDataSegments {
            for formantDataSegment in formantDataSegments {
                let formantDataSet = LineChartDataSet(entries: formantDataSegment)
                formantDataSet.drawCirclesEnabled = false
                formantDataSet.drawValuesEnabled = false
                formantDataSet.drawIconsEnabled = false
                formantDataSet.mode = .horizontalBezier
                formantDataSet.lineWidth = Self.LINE_WIDTH
                formantDataSet.lineDashLengths = [5, 5]
                formantDataSet.setColor(UIColor(Color.accentColor))
                dataSets.append(formantDataSet)
            }
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
        if let highlightedFrameIndex = highlightedFrameIndex,
           let pitchDataSegmentIndex = pitchDataSegments.findSegmentIndex(for: Int(highlightedFrameIndex)) {
            chart.highlightValue(x: Double(highlightedFrameIndex), dataSetIndex: pitchDataSegmentIndex, callDelegate: false)
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

extension Sequence where Element: Collection {
    func findSegmentIndex(for elementIndex: Int) -> Int? {
        var runningLength = 0
        for (segmentIndex, segment) in self.enumerated() {
            runningLength += segment.count
            if elementIndex < runningLength {
                return segmentIndex
            }
        }
        return nil
    }
}

extension Sequence {
    func group(by shouldGroupTogether: (_ prev: Element, _ next: Element) -> Bool) -> [[Element]] {
        var iter = makeIterator()
        var groups: [[Element]] = []
        var nextGroup: [Element] = []
        while let next = iter.next() {
            if let prev = nextGroup.last, !shouldGroupTogether(prev, next) {
                groups.append(nextGroup)
                nextGroup = []
            }
            nextGroup.append(next)
        }
        groups.append(nextGroup)
        return groups
    }
}
