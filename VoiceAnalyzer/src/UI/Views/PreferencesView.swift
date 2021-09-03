import SwiftUI
import VoiceAnalyzerRust

struct PreferencesView: View {
    @StateObject var preferences: AppPreferences

    var body: some View {
        Form {
            Section(header: Text("Pitch Estimation")) {
                Picker("Algorithm", selection: preferences.$pitchEstimationAlgorithm) {
                    Text("Yin").tag(PitchEstimationAlgorithmPreference.Yin)
                    Text("IRAPT").tag(PitchEstimationAlgorithmPreference.IRAPT)
                }
            }
        }
    }
}
