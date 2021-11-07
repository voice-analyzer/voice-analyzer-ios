import os
import Foundation
import SwiftUI

struct LivePitchChart: View {
    @Binding var isPresented: Bool
    @ObservedObject var voiceRecorder: VoiceRecorderModel
    @ObservedObject var voiceRecording: VoiceRecordingModel
    @ObservedObject var analysis: PitchChartAnalysisFrames
    @State var limitLines: PitchChartLimitLines = PitchChartLimitLines(lower: nil, upper: nil)

    @Environment(\.env) var env: AppEnvironment

    @State private var isRecording = false
    @State private var preferencesIsPresented = false
    @State private var highlightedFrameIndex: UInt? = nil
    @State private var editingLimitLines: Bool = false
    @State private var editMode: EditMode = .inactive

    var body: some View {
        GeometryReader {
            geometry in
            VStack(spacing: 0) {
                chartView
                Divider()
                ZStack {
                    toolbarView
                }
                .frame(height: 44 + geometry.safeAreaInsets.bottom, alignment: .top)
                .background(Color(UIColor.secondarySystemBackground))
            }
            .ignoresSafeArea(.all, edges: .bottom)
            .navigationBarTitle("Pitch Estimation")
            .navigationBarTitleDisplayMode(.inline)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if editingLimitLines {
                    EditButton()
                }
            }
        }
        .environment(\.editMode, $editMode)
        .onChange(of: editingLimitLines) { _ in
            editMode = editingLimitLines ? .active : .inactive
        }
        .onChange(of: editMode) { _ in
            if editMode == .inactive {
                if editingLimitLines {
                    if let lowerLimitLine = limitLines.lower {
                        env.preferences.lowerLimitLine = lowerLimitLine
                    }
                    if let upperLimitLine = limitLines.upper {
                        env.preferences.upperLimitLine = upperLimitLine
                    }
                    editingLimitLines = false
                }
            }
        }
        .onAppear {
            limitLines = PitchChartLimitLines(
                lower: env.preferences.lowerLimitLine,
                upper: env.preferences.upperLimitLine
            )
            do {
                try voiceRecorder.start(env: env, recording: voiceRecording)
                isRecording = voiceRecorder.isRecording
            } catch let error {
                os_log("error starting recording: \(error.localizedDescription)")
            }
        }
        .onDisappear {
            voiceRecorder.stop(env: env)
            isRecording = voiceRecorder.isRecording
        }
    }

    var chartView: some View {
        ChartView(
            analysis: analysis,
            highlightedFrameIndex: $highlightedFrameIndex,
            limitLines: $limitLines,
            editingLimitLines: editingLimitLines
        )
            .onReceive(voiceRecording.frames.receive(on: DispatchQueue.main)) { update in
                switch update {
                case .append(let frame):
                    analysis.append(frame: frame.frame, tentativeFrames: frame.tentativeFrames)
                case .clear:
                    analysis.removeAll()
                }
            }
    }

    var toolbarView: some View {
        ZStack {
            HStack {
                preferencesButton
                Spacer()
            }
            HStack {
                Spacer()
                recordButton
                Spacer()
            }
            HStack(spacing: 16) {
                Spacer()
                saveButton
                clearButton
            }
        }
        .font(.system(size: 18))
        .imageScale(.large)
        .padding(.horizontal, 16)
        .frame(height: 44)
    }

    var preferencesButton: some View {
        Button(action: {
            preferencesIsPresented = true
        }) {
            Image(systemName: "gear")
        }
        .sheet(isPresented: $preferencesIsPresented) {
            PreferencesView(preferences: env.preferences, isPresented: $preferencesIsPresented, editingLimitLines: $editingLimitLines)
        }
    }

    var recordButton: some View {
        Button(action: {
            do {
                try voiceRecorder.toggle(env: env, recording: voiceRecording)
                isRecording = voiceRecorder.isRecording
            } catch let error {
                os_log("error toggling recording: \(error.localizedDescription)")
            }
        }) {
            Image(systemName: isRecording ? "pause" : "mic")
        }
    }

    var clearButton: some View {
        Button(action: {
            voiceRecording.clear()
        }) {
            Image(systemName: "trash")
        }
        .accentColor(Color.red)
    }

    var saveButton: some View {
        Button(action: {
            do {
                let metadata = VoiceRecordingMetadata(
                    lowerLimitLine: limitLines.lower,
                    upperLimitLine: limitLines.upper
                )
                try voiceRecording.save(env: env, metadata: metadata)
                isPresented = false
            } catch let error {
                os_log("error saving recording: \(error.localizedDescription)")
            }
            voiceRecorder.stop(env: env)
        }) {
            Image(systemName: "square.and.arrow.down")
        }
    }
}
