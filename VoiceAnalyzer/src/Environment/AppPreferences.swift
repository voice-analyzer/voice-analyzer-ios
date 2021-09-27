import Combine
import Foundation
import SwiftUI

public class AppPreferences: ObservableObject {
    @AppStorage("pitchEstimationAlgorithm")
    var pitchEstimationAlgorithm: PitchEstimationAlgorithmPreference = .Yin

    @AppStorage("formantEstimationEnabled")
    var formantEstimationEnabled: Bool = false
}

public enum PitchEstimationAlgorithmPreference: Int {
    case IRAPT, Yin
}
