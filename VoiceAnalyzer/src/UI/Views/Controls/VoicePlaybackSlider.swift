import Foundation
import SwiftUI
import os

struct VoicePlaybackSlider: View {
    @ObservedObject var playback: VoicePlaybackModel
    @Binding var pausedPlayback: Bool
    var recordingLength: Float

    var body: some View {
        VStack(spacing: 0) {
            VoicePlaybackSliderBar(playback: playback, pausedPlayback: $pausedPlayback, maximumValue: recordingLength)
            HStack {
                Text(formatRecordingLength(playback.currentTime))
                Spacer()
                Text(formatRecordingLength(playback.currentTime - recordingLength))
            }
            .foregroundColor(.secondary)
            .font(.caption)
        }
    }
}

struct VoicePlaybackSliderBar: UIViewRepresentable {
    @ObservedObject var playback: VoicePlaybackModel
    @Binding var pausedPlayback: Bool
    var maximumValue: Float

    @Environment(\.env) private var env: AppEnvironment

    func makeUIView(context: Context) -> UISlider {
        let slider = UISlider()
        slider.maximumValue = maximumValue

        slider.minimumTrackTintColor = UIColor.systemGray
        slider.maximumTrackTintColor = UIColor.secondarySystemFill

        let thumbImageConfiguration = UIImage.SymbolConfiguration(scale: .small)
        let thumbImage = UIImage(systemName: "circle.fill", withConfiguration: thumbImageConfiguration)!
            .withTintColor(slider.minimumTrackTintColor!, renderingMode: .alwaysOriginal)
        slider.setThumbImage(thumbImage, for: .disabled)
        slider.setThumbImage(thumbImage, for: .normal)
        slider.setThumbImage(thumbImage, for: .selected)
        slider.setThumbImage(thumbImage, for: .highlighted)

        slider.addTarget(context.coordinator, action: #selector(Coordinator.updateValue(slider:)), for: .valueChanged)
        slider.addTarget(context.coordinator, action: #selector(Coordinator.sliderTouchDown(slider:)), for: .touchDown)
        slider.addTarget(context.coordinator, action: #selector(Coordinator.sliderTouchUp(slider:)), for: .touchUpInside)
        slider.addTarget(context.coordinator, action: #selector(Coordinator.sliderTouchUp(slider:)), for: .touchUpOutside)

        return slider
    }

    func updateUIView(_ slider: UISlider, context: Context) {
        slider.maximumValue = maximumValue
        slider.setValue(playback.currentTime, animated: true)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject {
        let slider: VoicePlaybackSliderBar

        init(_ slider: VoicePlaybackSliderBar) {
            self.slider = slider
        }

        @objc func updateValue(slider: UISlider) {
            self.slider.playback.currentTime = slider.value
        }

        @objc func sliderTouchDown(slider: UISlider) {
            if self.slider.playback.isPlaying {
                self.slider.playback.pausePlayback(env: self.slider.env)
                self.slider.pausedPlayback = true
            }
        }

        @objc func sliderTouchUp(slider: UISlider) {
            if self.slider.pausedPlayback {
                self.slider.pausedPlayback = false
                do {
                    try self.slider.playback.resumePlayback(env: self.slider.env)
                } catch {
                    os_log("error resuming playback: %@", error.localizedDescription)
                }
            }
        }
    }
}

private func formatRecordingLength(_ length: Float) -> String {
    let interval = TimeInterval(length)
    let formatter = DateComponentsFormatter()
    formatter.unitsStyle = .positional
    if interval >= 60 * 60 {
        formatter.allowedUnits = [.hour, .minute, .second]
    } else {
        formatter.allowedUnits = [.minute, .second]
    }
    formatter.zeroFormattingBehavior = .pad
    formatter.maximumUnitCount = 2
    if let formatted = formatter.string(from: interval) {
        if length.sign == .minus {
            return "-\(formatted)"
        } else {
            return formatted
        }
    } else {
        return "??:??"
    }
}
