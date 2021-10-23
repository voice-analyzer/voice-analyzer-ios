import SwiftUI
import Charts

struct PitchChartLimitLines: Equatable {
    let lower: Double?
    let upper: Double?

    init(lower: Double?, upper: Double?) {
        self.lower = lower
        self.upper = upper
    }

    init(_ first: Double?, _ second: Double?) {
        switch (first, second) {
        case (.some(let lower), .some(let upper)) where lower <= upper:
            self.init(lower: lower, upper: upper)
        case (.some(let upper), .some(let lower)):
            self.init(lower: lower, upper: upper)
        case (.some(let lower), .none), (.none, .some(let lower)):
            self.init(lower: lower, upper: nil)
        case (.none, .none):
            self.init(lower: nil, upper: nil)
        }
    }
}

struct PitchChart: UIViewRepresentable {
    typealias UIViewType = UIPitchChart

    @Binding var highlightedFrameIndex: UInt?
    @Binding var limitLines: PitchChartLimitLines
    let editingLimitLines: Bool

    private static let LINE_WIDTH = 3.0
    private static let MAX_LINE_SEGMENT_JUMP_IN_Y = 0.75

    private static let PITCH_RANGE = 55.0 ... 880.0

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
            .filter { frame in Self.PITCH_RANGE.contains(Double(frame.pitchFrequency)) }

        pitchDataSegments = voicedFrames
            .enumerated()
            .lazy
            .compactMap { index, frame in
                guard let musicalPitch = MusicalPitch(fromHz: Double(frame.pitchFrequency)) else { return nil }
                return ChartDataEntry(x: Double(index), y: musicalPitch.value)
            }
            .group { a, b in abs(a.y - b.y) <= Self.MAX_LINE_SEGMENT_JUMP_IN_Y }

        var formantsData: [[ChartDataEntry]] = []
        for (frameIndex, frame) in voicedFrames.enumerated() {
            let frameFormants = frame.formantFrequencies
            if frameFormants.count > formantsData.count {
                formantsData.append(contentsOf: Array(repeating: [], count: frameFormants.count - formantsData.count))
            }
            for (formantIndex, formant) in frameFormants.enumerated() {
                if Self.PITCH_RANGE.contains(Double(formant)),
                   let formantMusicalPitch = MusicalPitch(fromHz: Double(formant))
                {
                    formantsData[formantIndex]
                        .append(ChartDataEntry(x: Double(frameIndex), y: formantMusicalPitch.value))
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
        chart.leftAxis.axisMinimum = MusicalPitch(fromHz: Self.PITCH_RANGE.lowerBound)!.value
        chart.leftAxis.axisMaximum = MusicalPitch(fromHz: Self.PITCH_RANGE.upperBound)!.value
        chart.leftAxis.labelCount = 8

        chart.rightAxis.enabled = false
        // work around Charts crash on clearing data when zoomed in
        chart.rightAxis.axisMinimum = 0
        chart.rightAxis.axisMaximum = 1

        chart.delegate = context.coordinator

        chart.panGestureRecognizer = UIPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.panGestureRecognized(_:))
        )

        updateDataSet(chart: chart)
        updateLimitLines(chart: chart)
        updateHighlight(chart: chart)
        return chart
    }

    func updateUIView(_ chart: UIViewType, context: Context) {
        updateDataSet(chart: chart)
        updateLimitLines(chart: chart)
        updateHighlight(chart: chart)
        chart.notifyDataSetChanged()
    }

    func updateDataSet(chart: UIViewType) {
        let lineColor = editingLimitLines ? chart.leftAxis.axisLineColor.withAlphaComponent(0.5) : UIColor(.accentColor)

        var dataSets: [LineChartDataSet] = []
        if !pitchDataSegments.isEmpty {
            for pitchDataSegment in pitchDataSegments {
                let pitchDataSet = LineChartDataSet(entries: pitchDataSegment)
                pitchDataSet.drawCirclesEnabled = false
                pitchDataSet.drawValuesEnabled = false
                pitchDataSet.drawIconsEnabled = false
                pitchDataSet.lineWidth = Self.LINE_WIDTH
                pitchDataSet.setColor(lineColor)
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
                formantDataSet.setColor(lineColor)
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
        chart.leftAxis.removeAllLimitLines()

        if let lowerLimitLine = limitLines.lower,
           let lowerLimitLinePitch = MusicalPitch(fromHz: lowerLimitLine)
        {
            chart.leftAxis.addLimitLine(ChartLimitLine(
                limit: lowerLimitLinePitch.value,
                label: lowerLimitLinePitch.closestNote().description()
            ))
        }

        if let upperLimitLine = limitLines.upper,
           let upperLimitLinePitch = MusicalPitch(fromHz: upperLimitLine)
        {
            chart.leftAxis.addLimitLine(ChartLimitLine(
                limit: upperLimitLinePitch.value,
                label: upperLimitLinePitch.closestNote().description()
            ))
        }

        for limitLine in chart.leftAxis.limitLines {
            if editingLimitLines {
                limitLine.lineColor = UIColor(.accentColor)
                limitLine.lineWidth = 5.0
            } else {
                limitLine.lineColor = chart.leftAxis.axisLineColor
                limitLine.lineWidth = 3.0
            }
        }

        if editingLimitLines {
            if chart.gestureRecognizers?.contains(chart.panGestureRecognizer!) != true {
                chart.addGestureRecognizer(chart.panGestureRecognizer!)
            }
        } else {
            chart.removeGestureRecognizer(chart.panGestureRecognizer!)
        }
        chart.leftAxis.drawLimitLinesBehindDataEnabled = !editingLimitLines
        chart.dragEnabled = !editingLimitLines
    }

    func updateHighlight(chart: UIViewType) {
        if !editingLimitLines,
           let highlightedFrameIndex = highlightedFrameIndex,
           let pitchDataSegmentIndex = pitchDataSegments.findSegmentIndex(for: Int(highlightedFrameIndex)) {
            chart.highlightValue(x: Double(highlightedFrameIndex), dataSetIndex: pitchDataSegmentIndex, callDelegate: false)
        } else {
            chart.highlightValue(nil)
        }
    }

    private func checkLimitLineTouched(chart: UIViewType, gestureY: Double, limitLine: Double) -> Bool {
        guard let limitLinePitch = MusicalPitch(fromHz: limitLine) else { return false }
        let limitLineY = chart.getTransformer(forAxis: .left).pixelForValues(x: 0, y: limitLinePitch.value).y
        return abs(limitLineY - gestureY) < 30
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }

    class Coordinator: NSObject, ChartViewDelegate {
        let chart: PitchChart

        enum LimitLineDragState {
            case upper, lower
        }

        var limitLineDragState: LimitLineDragState?

        init(_ chart: PitchChart) {
            self.chart = chart
        }

        func chartValueSelected(_ chartView: ChartViewBase, entry: ChartDataEntry, highlight: Highlight) {
            chart.highlightedFrameIndex = UInt(entry.x)
        }

        @objc func panGestureRecognized(_ recognizer: UIPanGestureRecognizer) {
            guard let uiChart = recognizer.view as? UIViewType else { return }

            let gestureY = recognizer.location(in: uiChart).y
            let gestureChartY = uiChart.getTransformer(forAxis: .left).valueForTouchPoint(x: 0, y: gestureY).y
            let gestureChartHz = MusicalPitch(value: gestureChartY)?.hz()

            switch (recognizer.state, limitLineDragState) {
            case (.began, _):
                let translateY = recognizer.translation(in: uiChart).y
                let gestureStartY = gestureY - translateY
                if let upperLimitLine = chart.limitLines.upper,
                   chart.checkLimitLineTouched(chart: uiChart, gestureY: gestureStartY, limitLine: upperLimitLine)
                {
                    limitLineDragState = .upper
                } else if
                    let lowerLimitLine = chart.limitLines.lower,
                    chart.checkLimitLineTouched(chart: uiChart, gestureY: gestureStartY, limitLine: lowerLimitLine)
                {
                    limitLineDragState = .lower
                } else {
                    limitLineDragState = nil
                }
            case (.changed, .upper):
                if let gestureChartHz = gestureChartHz, PitchChart.PITCH_RANGE.contains(gestureChartHz) {
                    chart.limitLines = PitchChartLimitLines(lower: chart.limitLines.lower, upper: gestureChartHz)
                }
            case (.changed, .lower):
                if let gestureChartHz = gestureChartHz, PitchChart.PITCH_RANGE.contains(gestureChartHz) {
                    chart.limitLines = PitchChartLimitLines(lower: gestureChartHz, upper: chart.limitLines.upper)
                }
            case (.ended, .some(_)):
                limitLineDragState = nil
            default:
                break
            }
        }
    }
}

class UIPitchChart: LineChartView {
    internal var panGestureRecognizer: UIPanGestureRecognizer?
}

class HzValueFormatter: IAxisValueFormatter {
    func stringForValue(_ value: Double, axis: AxisBase?) -> String {
        guard let musicalPitch = MusicalPitch(value: value) else { return "" }
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
