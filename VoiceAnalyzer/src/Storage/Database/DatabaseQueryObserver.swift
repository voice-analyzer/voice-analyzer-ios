import os
import Combine
import Foundation
import GRDB

class DatabaseQueryObserver<T>: ObservableObject {
    var query: (Database) throws -> T {
        willSet {
            objectWillChange.send()
            cancellable = nil
        }
    }
    private(set) var value: T

    private var db: DatabaseReader?
    private var cancellable: AnyCancellable?

    init(initialValue: T, query: @escaping (Database) throws -> T) {
        value = initialValue
        self.query = query
    }

    func observe(db: DatabaseReader) {
        if let _ = cancellable { return }
        self.db = db
        cancellable = ValueObservation
            .tracking(query)
            .publisher(in: db)
            .sink(receiveCompletion: { completion in
                switch completion {
                case .failure(let error):
                    os_log("error querying database: \(error.localizedDescription)")
                case .finished:
                    break
                }
            }, receiveValue: { [weak self] value in
                guard let self = self else { return }
                self.objectWillChange.send()
                self.value = value
            })
    }
}
