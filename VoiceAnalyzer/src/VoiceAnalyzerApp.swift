import os
import SwiftUI
import Charts
import VoiceAnalyzerRust

@main
struct VoiceAnalyzerApp: App {
    @Environment(\.env) var env: AppEnvironment

    @StateObject private var voiceRecording: VoiceRecordingModel = VoiceRecordingModel()
    @State private var isRecording = false

    var body: some Scene {
        WindowGroup {
            NavigationView {
                VStack {
                    ChartView(analysisFrames: $voiceRecording.frames)
                    HStack {
                        NavigationLink(destination: PreferencesView(preferences: env.preferences)) {
                            Image(systemName: "gear")
                                .accessibilityLabel("Preferences")
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
                .navigationBarHidden(true)
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
        }
    }
}
