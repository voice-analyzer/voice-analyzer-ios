import Combine
import Foundation
import SwiftUI
import VoiceAnalyzerRust

public class AppPreferences: ObservableObject {
    @AppStorage("pitchEstimationAlgorithm")
    var pitchEstimationAlgorithm: PitchEstimationAlgorithmPreference = .Yin
}

public enum PitchEstimationAlgorithmPreference: Int {
    case IRAPT, Yin
}
