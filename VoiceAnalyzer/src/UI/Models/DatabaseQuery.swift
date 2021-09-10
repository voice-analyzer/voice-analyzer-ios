import Foundation
import GRDB
import SwiftUI
import os

@propertyWrapper
struct DatabaseQuery<T>: DynamicProperty {
    @Environment(\.env) private var env: AppEnvironment
    @StateObject private var observer: DatabaseQueryObserver<T>

    var wrappedValue: T { observer.value }

    var projectedValue: Binding<(Database) throws -> T> {
        Binding(
            get: { observer.query },
            set: { query in observer.query = query }
        )
    }

    init(wrappedValue: T, _ query: @escaping (Database) throws -> T) {
        _observer = StateObject(wrappedValue: DatabaseQueryObserver(initialValue: wrappedValue, query: query))
    }

    func update() {
        observer.observe(db: env.databaseStorage.reader())
    }
}
