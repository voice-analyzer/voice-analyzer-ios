import Foundation
import GRDB
import os

let BUSY_WAIT_INTERVAL = useconds_t(15 * 1000)
let BUSY_WAIT_LOG_INTERVAL = 5

class DatabaseStorage {
    static var logQueries: Bool = false

    private let grdbStorage: GRDBStorage

    init() throws {
        let grdbUrl = try AppFilesystem.appDocumentDirectory().appendingPathComponent("app.sqlite")
        grdbStorage = try GRDBStorage(url: grdbUrl)
        grdbStorage.asyncMigrate(completion: { _db, error in
            if let error = error {
                fatalError("database migration completed with an error: \(error)")
            }
            os_log("database migration completed")
        })
    }

    func reader() -> AnyDatabaseReader {
        AnyDatabaseReader(grdbStorage.pool)
    }

    func writer() -> AnyDatabaseWriter {
        AnyDatabaseWriter(grdbStorage.pool)
    }
}

struct DatabaseRecords {
}

private struct GRDBStorage {
    let pool: DatabasePool

    init(url: URL) throws {
        let config = Self.config()
        pool = try DatabasePool(path: url.path, configuration: config)
    }

    static func config() -> Configuration {
        var config = Configuration()
        config.label = "GRDB Storage"
        config.defaultTransactionKind = .immediate
        config.prepareDatabase { db in
            db.trace(options: .statement) { logMessage in
                if DatabaseStorage.logQueries {
                    os_log("database queried: \(logMessage.description)")
                }
            }
        }
        config.busyMode = .callback { retryCount in
            usleep(BUSY_WAIT_INTERVAL)
            if retryCount % BUSY_WAIT_LOG_INTERVAL == 0 {
                let busyTime = retryCount * Int(BUSY_WAIT_INTERVAL) * 1000
                os_log("database busy for \(busyTime)ms")
            }
            return true
        }
        return config
    }

    func asyncMigrate(completion: @escaping (Database, Error?) -> Void) {
        var migrator = DatabaseMigrator()
        for migration in GRDBMigration.allCases {
            migrator.registerMigration(migration.migrationId) { db in
                do {
                    if try !db.tableExists(SkippedMigration.databaseTableName)
                        || SkippedMigration.fetchOne(db, key: migration.migrationId) == nil
                    {
                        os_log("running database migration \(migration.migrationId)")
                        try migration.migrate(db)
                    } else {
                        os_log("skipping database migration \(migration.migrationId)")
                    }
                } catch let error {
                    fatalError("error in migration \(migration.migrationId): \(error)")
                }
            }
        }

        migrator.asyncMigrate(pool, completion: completion)
    }
}

private enum GRDBMigration: String, CaseIterable {
    case latestSchema

    var migrationId: String { rawValue }

    func migrate(_ db: Database) throws {
        switch self {
        case .latestSchema:
            let schemaUrl = Bundle(for: DatabaseStorage.self).url(forResource: "schema", withExtension: "sql")!
            let schemaSql = try String(contentsOf: schemaUrl)
            try db.execute(sql: schemaSql)
            for migration in Self.allCases {
                try SkippedMigration(migrationId: migration.migrationId).insert(db)
            }
        }
    }
}

private struct SkippedMigration: Codable, FetchableRecord, PersistableRecord {
    let migrationId: String
}
