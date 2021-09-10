import os
import AVFoundation

public class AudioSession {
    private let audioSession = AVAudioSession.sharedInstance()

    private var activityWeakRefs: [Weak<Activity>] = []

    public init() {
        updateCategory()
    }

    public func startActivity(_ activity: Activity) {
        activity.session = self
        self.activityWeakRefs.append(Weak(activity))
        updateCategory()
    }

    public func endActivity(_ activity: Activity) {
        activityWeakRefs.removeAll { ObjectIdentifier(activity) == $0.value.map({ ObjectIdentifier($0) }) }

        if let session = activity.session, ObjectIdentifier(session) == ObjectIdentifier(self) {
            activity.session = nil
        }

        updateCategory()
    }

    func cleanupActivities() -> [Activity] {
        let activities = activityWeakRefs.compactMap { $0.value }
        activityWeakRefs = activities.compactMap { Weak($0) }
        return activities
    }

    func updateCategory() {
        let category = calculateCategory(activities: cleanupActivities())
        if let category = category {
            do {
                try audioSession.setCategory(category)
                try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
                os_log("activated audio session with category %@", category.rawValue)
            } catch {
                os_log("error activating audio session with category %@", category.rawValue)
            }
        } else {
            do {
                try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
                try audioSession.setCategory(.soloAmbient)
                os_log("deactivated audio session")
            } catch {
                os_log("error deactivating audio session")
            }
        }
    }
    func calculateCategory(activities: [Activity]) -> AVAudioSession.Category? {
        let categories = Set(activities.compactMap { $0.category })
        let playback = categories.contains(.playback)
        let record = categories.contains(.record)
        if playback && record || categories.contains(.playAndRecord) {
            return .playAndRecord
        } else if record {
            return .record
        } else if playback {
            return .playback
        } else {
            return nil
        }
    }

    public class Activity {
        let category: AVAudioSession.Category
        var session: AudioSession?

        public init(category: AVAudioSession.Category) {
            self.category = category
        }

        deinit {
            session?.updateCategory()
        }
    }
}
