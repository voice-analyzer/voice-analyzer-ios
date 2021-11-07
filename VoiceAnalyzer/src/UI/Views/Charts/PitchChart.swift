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

class PitchChartAnalysisFrames: ObservableObject {
    private static let MAX_LINE_SEGMENT_JUMP_IN_Y = 0.75

    fileprivate var pitchRange = 55.0 ... 880.0
    fileprivate var confidenceThreshold: Float = 0.20

    @Published fileprivate var pitchDataEntryPointers: [DataEntryPointer] = []
    @Published fileprivate var pitchDataSegments: [[PitchChartPitchDataEntry]] = []
    @Published fileprivate var tentativePitchData: [ChartDataEntry]?
    @Published fileprivate var formantsDataSegments: [[[ChartDataEntry]]] = []
    @Published fileprivate var clearCount = 0

    func replaceAll<Frames: Collection, TentativeFrames: Collection>(analysisFrames: Frames, tentativeAnalysisFrames: TentativeFrames)
    where Frames.Element == AnalysisFrame, TentativeFrames.Element == AnalysisFrame
    {
        let confidenceThreshold = self.confidenceThreshold
        let pitchRange = self.pitchRange

        let voicedFrames = analysisFrames
            .lazy
            .enumerated()
            .filter { index, frame in frame.pitchConfidence > confidenceThreshold }
            .filter { index, frame in pitchRange.contains(Double(frame.pitchFrequency)) }
            .enumerated()
            .map { index, frame in (index, frame.0, frame.1 ) }

        var pitchDataEntryPointers: [DataEntryPointer] = []
        pitchDataSegments = voicedFrames
            .compactMap { index, analysisFrameIndex, frame in
                guard let pitch = MusicalPitch(fromHz: Double(frame.pitchFrequency)) else { return nil }
                return (index, analysisFrameIndex, pitch)
            }
            .group { (a: (Int, Int, MusicalPitch), b) in abs(a.2.value - b.2.value) <= Self.MAX_LINE_SEGMENT_JUMP_IN_Y } mapping: {
                segmentIndex, dataEntryIndex, frame in
                let (index, analysisFrameIndex, musicalPitch) = frame

                let distance = analysisFrameIndex + 1 - pitchDataEntryPointers.count
                if distance > 0 {
                    let prevPointer = pitchDataEntryPointers.last
                    let nextPointer = DataEntryPointer(segmentIndex: segmentIndex, dataEntryIndex: dataEntryIndex)
                    for _ in 0..<distance / 2 {
                        pitchDataEntryPointers.append(prevPointer ?? nextPointer)
                    }
                    for _ in distance / 2..<distance {
                        pitchDataEntryPointers.append(nextPointer)
                    }
                }

                return PitchChartPitchDataEntry(index: index, pitch: musicalPitch.value, analysisFrameIndex: analysisFrameIndex)
            }
        self.pitchDataEntryPointers = pitchDataEntryPointers

        var formantsData: [[ChartDataEntry]] = []
        for (frameIndex, _, frame) in voicedFrames {
            let frameFormants = frame.formantFrequencies
            if frameFormants.count > formantsData.count {
                formantsData.append(contentsOf: Array(repeating: [], count: frameFormants.count - formantsData.count))
            }
            for (formantIndex, formant) in frameFormants.enumerated() {
                if pitchRange.contains(Double(formant)),
                   let formantMusicalPitch = MusicalPitch(fromHz: Double(formant))
                {
                    formantsData[formantIndex]
                        .append(ChartDataEntry(x: Double(frameIndex), y: formantMusicalPitch.value))
                }
            }
        }
        formantsDataSegments = formantsData
            .map { formantData in formantData.group { a, b in abs(a.y - b.y) <= Self.MAX_LINE_SEGMENT_JUMP_IN_Y } }

        setTentative(tentativeAnalysisFrames: tentativeAnalysisFrames)
    }

    private func setTentative<Frames: Collection>(tentativeAnalysisFrames: Frames) where Frames.Element == AnalysisFrame {
        let lastPitchDataEntry = pitchDataSegments.last?.last
        let tentativePitchDataStartX = (lastPitchDataEntry?.x).map { x in Double(x) } ?? 0.0
        let tentativePitchDataEntries = tentativeAnalysisFrames
            .lazy
            .enumerated()
            .map { index, frame -> ChartDataEntry in
                let musicalPitch = MusicalPitch(fromHz: Double(frame.pitchFrequency).clamped(pitchRange))!
                return ChartDataEntry(
                    x: tentativePitchDataStartX + Double(index) / Double(tentativeAnalysisFrames.count),
                    y: musicalPitch.value
                )
            }
        if !tentativeAnalysisFrames.isEmpty {
            if let lastPitchDataEntry = lastPitchDataEntry,
               let firstTentativePitchDataEntry = tentativePitchDataEntries.first,
               abs(firstTentativePitchDataEntry.y - lastPitchDataEntry.y) < Self.MAX_LINE_SEGMENT_JUMP_IN_Y {
                tentativePitchData = Array([
                    AnySequence([lastPitchDataEntry].compactMap { $0 }),
                    AnySequence(tentativePitchDataEntries)
                ].joined())
            } else {
                tentativePitchData = tentativePitchDataEntries
            }
        } else {
            tentativePitchData = nil
        }
    }

    func append<TentativeFrames: Collection>(frame: AnalysisFrame, tentativeFrames: TentativeFrames)
    where TentativeFrames.Element == AnalysisFrame
    {
        if frame.pitchConfidence > confidenceThreshold,
           pitchRange.contains(Double(frame.pitchFrequency)),
           let musicalPitch = MusicalPitch(fromHz: Double(frame.pitchFrequency))
        {
            let index = (pitchDataSegments.last?.last?.x).map { x in Int(x) + 1 } ?? 0

            if pitchDataSegments.isEmpty || abs(musicalPitch.value - pitchDataSegments.last!.last!.y) > Self.MAX_LINE_SEGMENT_JUMP_IN_Y {
                pitchDataSegments.append([])
            }
            let analysisFrameIndex = pitchDataEntryPointers.count
            let segmentIndex = pitchDataSegments.count - 1
            let segmentDataEntryIndex = pitchDataSegments[segmentIndex].count

            pitchDataEntryPointers.append(DataEntryPointer(segmentIndex: segmentIndex, dataEntryIndex: segmentDataEntryIndex))
            pitchDataSegments[segmentIndex].append(PitchChartPitchDataEntry(index: index, pitch: musicalPitch.value, analysisFrameIndex: analysisFrameIndex))

            let frameFormants = frame.formantFrequencies
            if frameFormants.count > formantsDataSegments.count {
                formantsDataSegments.append(contentsOf: Array(repeating: [], count: frameFormants.count - formantsDataSegments.count))
            }

            for (formantIndex, formant) in frameFormants.enumerated() {
                if pitchRange.contains(Double(formant)),
                   let formantMusicalPitch = MusicalPitch(fromHz: Double(formant))
                {
                    if formantsDataSegments[formantIndex].isEmpty ||
                        abs(formantMusicalPitch.value - formantsDataSegments[formantIndex].last!.last!.y) > Self.MAX_LINE_SEGMENT_JUMP_IN_Y
                    {
                        formantsDataSegments[formantIndex].append([])
                    }
                    let formantSegmentIndex = formantsDataSegments[formantIndex].count - 1
                    formantsDataSegments[formantIndex][formantSegmentIndex].append(ChartDataEntry(
                        x: Double(index),
                        y: formantMusicalPitch.value)
                    )
                }
            }
        }
        setTentative(tentativeAnalysisFrames: tentativeFrames)
    }

    func removeAll() {
        pitchDataEntryPointers = []
        pitchDataSegments = []
        tentativePitchData = nil
        formantsDataSegments = []
        clearCount += 1
    }
}

private struct DataEntryPointer {
    let segmentIndex: Int
    let dataEntryIndex: Int
}

struct PitchChart: UIViewRepresentable {
    typealias UIViewType = UIPitchChart

    @ObservedObject var analysis: PitchChartAnalysisFrames
    @Binding var highlightedFrameIndex: UInt?
    @Binding var limitLines: PitchChartLimitLines
    let editingLimitLines: Bool

    private static let LINE_WIDTH = 3.0

    init(
        analysis: PitchChartAnalysisFrames,
        highlightedFrameIndex: Binding<UInt?>,
        limitLines: Binding<PitchChartLimitLines>,
        editingLimitLines: Bool
    ) {
        _analysis = ObservedObject(initialValue: analysis)
        _highlightedFrameIndex = highlightedFrameIndex
        _limitLines = limitLines
        self.editingLimitLines = editingLimitLines
    }

    func makeUIView(context: Context) -> UIViewType {
        let chart = UIViewType()
        chart.legend.enabled = false

        chart.xAxis.drawGridLinesEnabled = false
        chart.xAxis.drawLabelsEnabled = false

        chart.leftAxis.valueFormatter = HzValueFormatter()
        chart.leftAxis.axisMinimum = MusicalPitch(fromHz: analysis.pitchRange.lowerBound)!.value
        chart.leftAxis.axisMaximum = MusicalPitch(fromHz: analysis.pitchRange.upperBound)!.value
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

        let data: ChartData
        if let chartData = chart.data {
            data = chartData
        } else {
            data = LineChartData()
            chart.data = data
        }

        if analysis.clearCount != chart.clearCount {
            chart.clearCount = analysis.clearCount
            chart.pitchDataSets = []
            chart.tentativePitchDataSet = nil
            chart.formantsDataSets = []
            data.clearValues()
        }

        if let dummyDataSet = chart.dummyDataSet {
            data.removeDataSet(dummyDataSet)
            chart.dummyDataSet = nil
        }

        for (segmentIndex, pitchDataSegment) in analysis.pitchDataSegments.lazy.enumerated() {
            if chart.pitchDataSets.count > segmentIndex {
                let pitchDataSetIndex = chart.pitchDataSets[segmentIndex]
                let pitchDataSetCount = data.dataSets[pitchDataSetIndex].entryCount
                for pitchDataEntry in pitchDataSegment.lazy.dropFirst(pitchDataSetCount) {
                    data.addEntry(pitchDataEntry, dataSetIndex: pitchDataSetIndex)
                }
                data.dataSets[pitchDataSetIndex].setColor(lineColor)
            } else {
                let pitchDataSet = LineChartDataSet(entries: pitchDataSegment)
                pitchDataSet.drawCirclesEnabled = false
                pitchDataSet.drawValuesEnabled = false
                pitchDataSet.drawIconsEnabled = false
                pitchDataSet.lineWidth = Self.LINE_WIDTH
                pitchDataSet.setColor(lineColor)
                pitchDataSet.mode = .horizontalBezier
                chart.pitchDataSets.append(data.dataSetCount)
                data.addDataSet(pitchDataSet)
            }
        }

        if let tentativePitchDataSetIndex = chart.tentativePitchDataSet {
            if data.dataSets[tentativePitchDataSetIndex].entryCount != 0 {
                data.dataSets[tentativePitchDataSetIndex].clear()
            }
            for tentativePitchDataEntry in analysis.tentativePitchData ?? [] {
                data.addEntry(tentativePitchDataEntry, dataSetIndex: tentativePitchDataSetIndex)
            }
            data.dataSets[tentativePitchDataSetIndex].setColor(lineColor.withAlphaComponent(0.5))
        } else if let tentativePitchData = analysis.tentativePitchData {
            let tentativePitchDataSet = LineChartDataSet(entries: tentativePitchData)
            tentativePitchDataSet.drawCirclesEnabled = false
            tentativePitchDataSet.drawValuesEnabled = false
            tentativePitchDataSet.drawIconsEnabled = false
            tentativePitchDataSet.lineWidth = Self.LINE_WIDTH
            tentativePitchDataSet.setColor(lineColor.withAlphaComponent(0.5))
            tentativePitchDataSet.highlightEnabled = false
            tentativePitchDataSet.mode = .horizontalBezier
            chart.tentativePitchDataSet = data.dataSetCount
            data.addDataSet(tentativePitchDataSet)
        }

        for (formantIndex, formantDataSegments) in analysis.formantsDataSegments.lazy.enumerated() {
            if chart.formantsDataSets.count == formantIndex {
                chart.formantsDataSets.append([])
            }
            for (segmentIndex, formantDataSegment) in formantDataSegments.lazy.enumerated() {
                if chart.formantsDataSets[formantIndex].count != segmentIndex {
                    let formantDataSetIndex = chart.formantsDataSets[formantIndex][segmentIndex]
                    let formantDataSetCount = data.dataSets[formantDataSetIndex].entryCount
                    for formantDataEntry in formantDataSegment.lazy.dropFirst(formantDataSetCount) {
                        data.addEntry(formantDataEntry, dataSetIndex: formantDataSetIndex)
                    }
                    data.dataSets[formantDataSetIndex].setColor(lineColor)
                } else {
                    let formantDataSet = LineChartDataSet(entries: formantDataSegment)
                    formantDataSet.drawCirclesEnabled = false
                    formantDataSet.drawValuesEnabled = false
                    formantDataSet.drawIconsEnabled = false
                    formantDataSet.mode = .horizontalBezier
                    formantDataSet.lineWidth = Self.LINE_WIDTH
                    formantDataSet.lineDashLengths = [5, 5]
                    formantDataSet.setColor(lineColor)
                    formantDataSet.highlightEnabled = false
                    chart.formantsDataSets[formantIndex].append(data.dataSetCount)
                    data.addDataSet(formantDataSet)
                }
            }
        }

        if chart.data?.dataSetCount == 0 {
            if chart.dummyDataSet == nil {
                let dummyDataEntries = [ChartDataEntry(x: 1, y: 0)]
                let dummyDataSet = LineChartDataSet(entries: dummyDataEntries)
                dummyDataSet.visible = false
                dummyDataSet.highlightEnabled = false
                chart.dummyDataSet = dummyDataSet
                chart.data?.addDataSet(dummyDataSet)
            }
        }
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
           highlightedFrameIndex < analysis.pitchDataEntryPointers.count
        {
            let pitchDataEntryPointer = analysis.pitchDataEntryPointers[Int(highlightedFrameIndex)]
            let pitchDataEntry = analysis.pitchDataSegments[pitchDataEntryPointer.segmentIndex][pitchDataEntryPointer.dataEntryIndex]
            let dataSetIndex = chart.pitchDataSets[pitchDataEntryPointer.segmentIndex]

            if !chart.highlighted.contains(where: { highlight in highlight.x == pitchDataEntry.x }) {
                chart.highlightValue(x: pitchDataEntry.x, dataSetIndex: dataSetIndex, callDelegate: false)
            }
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
            guard let entry = entry as? PitchChartPitchDataEntry else { return }
            guard let analysisFrameIndex = entry.analysisFrameIndex else { return }
            chart.highlightedFrameIndex = UInt(analysisFrameIndex)
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
                if let gestureChartHz = gestureChartHz, chart.analysis.pitchRange.contains(gestureChartHz) {
                    chart.limitLines = PitchChartLimitLines(lower: chart.limitLines.lower, upper: gestureChartHz)
                }
            case (.changed, .lower):
                if let gestureChartHz = gestureChartHz, chart.analysis.pitchRange.contains(gestureChartHz) {
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
    internal var pitchDataSets: [Int] = []
    internal var tentativePitchDataSet: Int?
    internal var formantsDataSets: [[Int]] = []
    internal var dummyDataSet: LineChartDataSet?
    internal var clearCount = 0
}

class HzValueFormatter: IAxisValueFormatter {
    func stringForValue(_ value: Double, axis: AxisBase?) -> String {
        guard let musicalPitch = MusicalPitch(value: value) else { return "" }
        let noteDescription = musicalPitch.closestNote().description()
        let intHzValue = Int(musicalPitch.hz())
        return "~\(noteDescription) (\(intHzValue)Hz)"
    }
}

extension Sequence {
    func group(by shouldGroupTogether: (_ prev: Element, _ next: Element) -> Bool) -> [[Element]] {
        group(by: shouldGroupTogether, mapping: { _, _, element in element })
    }
    func group<OutputElement>(
        by shouldGroupTogether: (_ prev: Element, _ next: Element) -> Bool,
        mapping: (_ groupIndex: Int, _ groupElementIndex: Int, _ element: Element) -> OutputElement
    ) -> [[OutputElement]] {
        var iter = makeIterator()
        var groups: [[OutputElement]] = []
        var nextGroup: [OutputElement] = []
        var prev: Element?
        while let next = iter.next() {
            if let prev = prev, !shouldGroupTogether(prev, next) {
                groups.append(nextGroup)
                nextGroup = []
            }
            prev = next
            nextGroup.append(mapping(groups.count, nextGroup.count, next))
        }
        if !nextGroup.isEmpty {
            groups.append(nextGroup)
        }
        return groups
    }
}

private class PitchChartPitchDataEntry: ChartDataEntry {
    let analysisFrameIndex: Int?

    required init() {
        analysisFrameIndex = nil
        super.init()
    }

    init(index: Int, pitch: Double, analysisFrameIndex: Int) {
        self.analysisFrameIndex = analysisFrameIndex
        super.init(x: Double(index), y: pitch)
    }
}
