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
