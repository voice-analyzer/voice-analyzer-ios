import Foundation
import GRDB

extension DatabaseRecords {
    struct AnalysisFrame: Codable, FetchableRecord, MutablePersistableRecord {
        var analysisId: Int64
        var time: Float
        var pitchFrequency: Float?
        var pitchConfidence: Float?
        var firstFormantFrequency: Float?
        var secondFormantFrequency: Float?

        enum Columns {
            static let analysisId = Column(CodingKeys.analysisId)
            static let time = Column(CodingKeys.time)
            static let pitchFrequency = Column(CodingKeys.pitchFrequency)
            static let pitchConfidence = Column(CodingKeys.pitchConfidence)
            static let firstFormantFrequency = Column(CodingKeys.firstFormantFrequency)
            static let secondFormantFrequency = Column(CodingKeys.secondFormantFrequency)
        }
    }
}
