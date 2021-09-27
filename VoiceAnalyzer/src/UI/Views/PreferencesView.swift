import SwiftUI

struct PreferencesView: View {
    @StateObject var preferences: AppPreferences
    @Binding var isPresented: Bool

    var body: some View {
        NavigationView {
            form
                .navigationTitle("Preferences")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigation) {
                        doneButton
                    }
                }
        }
    }

    var form: some View {
        Form {
            Section(header: Text("Pitch Estimation")) {
                Picker("Algorithm", selection: preferences.$pitchEstimationAlgorithm) {
                    Text("Yin").tag(PitchEstimationAlgorithmPreference.Yin)
                    Text("IRAPT").tag(PitchEstimationAlgorithmPreference.IRAPT)
                }
            }
            Section {
                VStack(alignment: .leading) {
                    Toggle(isOn: preferences.$formantEstimationEnabled) {
                        Text("Formant Estimation")
                    }
                    Text("Formants are measure of vocal resonance, which vary depending on the speaker and the vowel being spoken.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    var doneButton: some View {
        Button(action: {
            isPresented = false
        }) {
            Text("Done")
        }
    }
}
