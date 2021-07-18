import os
import SwiftUI
import Charts
import VoiceAnalyzerRust

@main
struct VoiceAnalyzerApp: App {
    private let env = Environment()

    @StateObject private var voiceRecording: VoiceRecordingModel = VoiceRecordingModel()

    var body: some Scene {
        WindowGroup {
            VStack {
                ChartView(pitches: $voiceRecording.pitches)
                Button(action: {
                    do {
                        try voiceRecording.toggleRecording(env: env)
                    } catch {
                        os_log("error starting recording: %@", error.localizedDescription)
                    }
                }) {
                    Text("Record/Stop")
                        .padding(.all, 5)
                        .border(Color.black)
                }
            }
        }
    }
}
