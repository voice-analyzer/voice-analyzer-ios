import Foundation
import SwiftUI

struct AppView: View {
    @Environment(\.colorScheme) private var colorScheme: ColorScheme
    @State private var livePitchChartIsPresented = true
    @State private var recordingsVisible = false
    @State private var recordingsEditMode: EditMode = .inactive
    @StateObject private var voiceRecording = VoiceRecordingModel()

    var body: some View {
        NavigationView {
            HStack {
                NavigationLink(destination: livePitchChart, isActive: $livePitchChartIsPresented) {
                    EmptyView()
                }
                // prevent recordings view flashing up on app start by hiding it before livePitchChart is presented (tested on iOS 14.5)
                if recordingsVisible {
                    recordingsView
                        .environment(\.editMode, $recordingsEditMode)
                }
            }
        }
    }

    var livePitchChart: some View {
        LivePitchChart(isPresented: $livePitchChartIsPresented, voiceRecording: voiceRecording)
            .onAppear {
                recordingsVisible = true
            }
    }

    var recordingsView: some View {
        GeometryReader {
            geometry in
            VStack(spacing: 0) {
                RecordingsView()
                if recordingsEditMode != .active {
                    ZStack(alignment: .top) {
                        livePitchChartButtonBar
                    }
                    .padding(.bottom, geometry.safeAreaInsets.bottom)
                    .background(Color(UIColor.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .transition(.move(edge: .bottom))
                }
            }
            .ignoresSafeArea(.all, edges: .bottom)
        }
    }

    var livePitchChartButtonBar: some View {
        HStack {
            Spacer()
            livePitchChartButton
            Spacer()
        }
        .padding(.vertical, 20)
    }

    var livePitchChartButton: some View {
        Button {
            livePitchChartIsPresented = true
        } label: {
            ZStack {
                Circle()
                    .stroke(lineWidth: 3)
                    .frame(width: 56, height: 56)
                    .foregroundColor(colorScheme == .light ? .secondary : .primary)
                Circle()
                    .frame(width: 47, height: 47)
                    .foregroundColor(.red)
            }
        }
    }
}
