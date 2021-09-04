import os
import SwiftUI
import Charts

@main
struct VoiceAnalyzerApp: App {
    @Environment(\.env) var env: AppEnvironment

    @StateObject private var voiceRecording: VoiceRecordingModel = VoiceRecordingModel()
    @State private var isRecording = false
    @State private var preferencesIsPresented = false

    var body: some Scene {
        WindowGroup {
            VStack {
                ChartView(analysisFrames: $voiceRecording.frames)
                HStack {
                    Button(action: {
                        preferencesIsPresented = true
                    }) {
                        Image(systemName: "gear")
                            .accessibilityLabel("Preferences")
                    }
                    .sheet(isPresented: $preferencesIsPresented) {
                        PreferencesView(preferences: env.preferences, isPresented: $preferencesIsPresented)
                    }
                    Spacer()
                    Button(action: {
                        do {
                            try voiceRecording.toggleRecording(env: env)
                            isRecording = voiceRecording.isRecording
                        } catch {
                            os_log("error toggling recording: %@", error.localizedDescription)
                        }
                    }) {
                        Text(isRecording ? "Stop" : "Record")
                    }
                    Spacer()
                    Button(action: {
                        voiceRecording.frames = []
                    }) {
                        Text("Clear")
                    }
                }
                .padding(.horizontal, 10)
            }
            .onAppear {
                do {
                    try voiceRecording.startRecording(env: env)
                    isRecording = voiceRecording.isRecording
                } catch {
                    os_log("error starting recording: %@", error.localizedDescription)
                }
            }
        }
    }
}
