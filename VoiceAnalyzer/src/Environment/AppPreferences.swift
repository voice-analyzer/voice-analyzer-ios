import Combine
import Foundation
import SwiftUI

public class AppPreferences: ObservableObject {
    @AppStorage("pitchEstimationAlgorithm")
    var pitchEstimationAlgorithm: PitchEstimationAlgorithmPreference = .Yin

    @AppStorage("formantEstimationEnabled")
    var formantEstimationEnabled: Bool = false

    @AppStorage("lowerLimitLine")
    var lowerLimitLine: Double = MusicalNote(note: 0, octave: 3).pitch().hz()

    @AppStorage("upperLimitLine")
    var upperLimitLine: Double = MusicalNote(note: 0, octave: 4).pitch().hz()
}

public enum PitchEstimationAlgorithmPreference: Int {
    case IRAPT, Yin
}
