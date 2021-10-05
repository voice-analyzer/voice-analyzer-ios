import os
import Foundation
import SwiftUI

struct LivePitchChart: View {
    @Binding var isPresented: Bool
    @ObservedObject var voiceRecording: VoiceRecordingModel

    @Environment(\.env) var env: AppEnvironment

    @State private var isRecording = false
    @State private var preferencesIsPresented = false
    @State private var highlightedFrameIndex: UInt? = nil

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
            .ignoresSafeArea(.container, edges: .bottom)
            .navigationBarTitle("Pitch Estimation")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            do {
                try voiceRecording.startRecording(env: env)
                isRecording = voiceRecording.isRecording
            } catch {
                os_log("error starting recording: %@", error.localizedDescription)
            }
        }
        .onDisappear {
            voiceRecording.stopRecording(env: env)
            isRecording = voiceRecording.isRecording
        }
    }

    var chartView: some View {
        ChartView(analysisFrames: voiceRecording.frames, highlightedFrameIndex: $highlightedFrameIndex)
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
            PreferencesView(preferences: env.preferences, isPresented: $preferencesIsPresented)
        }
    }

    var recordButton: some View {
        Button(action: {
            do {
                try voiceRecording.toggleRecording(env: env)
                isRecording = voiceRecording.isRecording
            } catch {
                os_log("error toggling recording: %@", error.localizedDescription)
            }
        }) {
            Image(systemName: isRecording ? "pause" : "mic")
        }
    }

    var clearButton: some View {
        Button(action: {
            voiceRecording.clearRecording()
        }) {
            Image(systemName: "trash")
        }
        .accentColor(Color.red)
    }

    var saveButton: some View {
        Button(action: {
            do {
                try voiceRecording.saveRecording(env: env)
                isPresented = false
            } catch {
                os_log("error saving recording: %@", error.localizedDescription)
            }
            voiceRecording.stopRecording(env: env)
        }) {
            Image(systemName: "square.and.arrow.down")
        }
    }
}
