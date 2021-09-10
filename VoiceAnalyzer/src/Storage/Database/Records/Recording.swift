import Foundation
import GRDB

extension DatabaseRecords {
    struct Recording: Codable, FetchableRecord, PersistableRecord {
        static let databaseDateEncodingStrategy = DatabaseDateEncodingStrategy.millisecondsSince1970
        static let databaseDateDecodingStrategy = DatabaseDateDecodingStrategy.millisecondsSince1970

        var id: Int64?
        var name: String?
        var timestamp: Date
        var length: Double
        var filename: String?
        var fileSize: Int64?

        var unwrappedId: Int64 { id! }

        enum Columns {
            static let id = Column(CodingKeys.id)
            static let name = Column(CodingKeys.name)
            static let timestamp = Column(CodingKeys.timestamp)
            static let length = Column(CodingKeys.length)
            static let filename = Column(CodingKeys.filename)
            static let fileSize = Column(CodingKeys.fileSize)
        }
    }
}
