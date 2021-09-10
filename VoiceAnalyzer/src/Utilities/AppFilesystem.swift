import Dispatch
import Foundation

public class AppFilesystem {
    private static var cache = AppFilesystemCache()

    static func appDocumentDirectory() throws -> URL {
        try cache.appDocumentDirectory.get {
            try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        }
    }

    static func appRecordingDirectory() throws -> URL {
        let appRecordingDirectory = try appDocumentDirectory().appendingPathComponent("Recordings")
        if !FileManager.default.fileExists(atPath: appRecordingDirectory.path) {
            try FileManager.default.createDirectory(at: appRecordingDirectory, withIntermediateDirectories: false)
        }
        return appRecordingDirectory
    }

    static func appTemporaryDirectory() throws -> URL {
        try cache.appTemporaryDirectory.get {
            FileManager.default.temporaryDirectory
        }
    }

    static func appLiveRecordingFile() throws -> URL {
        try appTemporaryDirectory().appendingPathComponent("Live Recording.pcm")
    }
}

class AppFilesystemCache {
    var appDocumentDirectory: Cached<URL> = Cached()
    var appTemporaryDirectory: Cached<URL> = Cached()
}

struct Cached<T> {
    var value: T?

    mutating func get(_ initializer: () throws -> T) throws -> T {
        if let value = value { return value }
        let value = try initializer()
        self.value = value
        return value
    }
}
