import os
import SwiftUI
import Charts
import VoiceAnalyzerRust

@main
struct VoiceAnalyzerApp: App {
    private let env = Environment()

    @StateObject private var voiceRecording: VoiceRecordingModel = VoiceRecordingModel()
    @State private var isRecording = false

    var body: some Scene {
        WindowGroup {
            VStack {
                ChartView(pitches: $voiceRecording.pitches)
                Button(action: {
                    do {
                        try voiceRecording.toggleRecording(env: env)
                        isRecording = voiceRecording.isRecording
                    } catch {
                        os_log("error toggling recording: %@", error.localizedDescription)
                    }
                }) {
                    Text(isRecording ? "Stop" : "Record")
                        .padding(.all, 5)
                        .border(Color.black)
                }
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
