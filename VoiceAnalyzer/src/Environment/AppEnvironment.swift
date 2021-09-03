import SwiftUI

public class AppEnvironment {
    static let shared = AppEnvironment()

    let audioSession = AudioSession()
    let preferences = AppPreferences()
}

struct AppEnvironmentKey: EnvironmentKey {
    static var defaultValue = AppEnvironment.shared
}

extension EnvironmentValues {
    var env: AppEnvironment {
        get { self[AppEnvironmentKey.self] }
        set { self[AppEnvironmentKey.self] = newValue }
    }
}
