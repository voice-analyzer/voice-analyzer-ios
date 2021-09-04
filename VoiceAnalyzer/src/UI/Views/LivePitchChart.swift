import os
import Foundation
import SwiftUI

struct LivePitchChart: View {
    @Environment(\.env) var env: AppEnvironment

    @StateObject private var voiceRecording: VoiceRecordingModel = VoiceRecordingModel()
    @State private var isRecording = false
    @State private var preferencesIsPresented = false

    var body: some View {
        GeometryReader {
            geometry in
            NavigationView {
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

    var chartView: some View {
        ChartView(analysisFrames: $voiceRecording.frames)
    }

    var toolbarView: some View {
        HStack {
            preferencesButton
            Spacer()
            recordButton
            Spacer()
            clearButton
        }
        .padding(.horizontal, 8)
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
            voiceRecording.frames = []
        }) {
            Image(systemName: "xmark")
        }
    }
}
