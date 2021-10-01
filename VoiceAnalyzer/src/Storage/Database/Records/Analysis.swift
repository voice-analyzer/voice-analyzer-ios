import Foundation
import GRDB

extension DatabaseRecords {
    struct Analysis: Codable, FetchableRecord, MutablePersistableRecord {
        var id: Int64?
        var recordingId: Int64
        var pitchEstimationAlgorithm: PitchEstimationAlgorithm?
        var formantEstimationAlgorithm: FormantEstimationAlgorithm?

        var unwrappedId: Int64 { id! }

        mutating func didInsert(with rowID: Int64, for column: String?) {
            id = rowID
        }

        enum Columns {
            static let id = Column(CodingKeys.id)
            static let recordingId = Column(CodingKeys.recordingId)
            static let pitchEstimationAlgorithm = Column(CodingKeys.pitchEstimationAlgorithm)
            static let formantEstimationAlgorithm = Column(CodingKeys.formantEstimationAlgorithm)
        }
    }

    enum PitchEstimationAlgorithm: Int, Codable {
        case Irapt = 0
        case Yin = 1
    }

    enum FormantEstimationAlgorithm: Int, Codable {
        case LibFormants = 0
    }
}
