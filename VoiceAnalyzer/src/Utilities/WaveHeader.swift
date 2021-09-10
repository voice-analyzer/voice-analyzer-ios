import Foundation

public struct WaveHeader {
    let dataLength: UInt32
    let dataFormat: WaveFormat
    let channelCount: UInt16
    let sampleRate: UInt32
    let bytesPerSample: UInt16

    public static func encodedLength(dataFormat: WaveFormat) -> UInt {
        switch dataFormat {
        case .PCM: return 44
        default: return 58
        }
    }

    public func encode() -> Data {
        let headerLength = Self.encodedLength(dataFormat: dataFormat)

        var data = Data(capacity: Int(headerLength))
        data.append(contentsOf: "RIFF".utf8)
        
        data.appendLittleEndian(dataLength + UInt32(headerLength) - 8)
        data.append(contentsOf: "WAVE".utf8)

        appendFmtChunk(data: &data)

        // for non-PCM formats only: fact chunk
        switch dataFormat {
        case .PCM: break
        default: appendFactChunk(data: &data)
        }

        // data chunk ID
        data.append(contentsOf: "data".utf8)
        // data chunk length
        data.appendLittleEndian(dataLength)
        return data
    }

    private func appendFmtChunk(data: inout Data) {
        // fmt chunk ID
        data.append(contentsOf: "fmt ".utf8)
        // fmt chunk length
        let chunkLength: UInt32
        switch dataFormat {
        case .PCM: chunkLength = 16
        default: chunkLength = 18
        }
        data.appendLittleEndian(chunkLength)
        // format code
        data.appendLittleEndian(dataFormat.rawValue)
        // channel count
        data.appendLittleEndian(channelCount)
        // sample rate
        data.appendLittleEndian(sampleRate)
        // data rate (in bytes per second)
        data.appendLittleEndian(sampleRate * UInt32(bytesPerSample) * UInt32(channelCount))
        // block alignment (bytes per sample)
        data.appendLittleEndian(bytesPerSample * channelCount)
        // bits per sample
        data.appendLittleEndian(bytesPerSample * 8)

        // for non-PCM formats only: extension length
        switch dataFormat {
        case .PCM: break
        default:
            data.appendLittleEndian(UInt16(0))
        }
    }

    private func appendFactChunk(data: inout Data) {
        // fact chunk ID
        data.append(contentsOf: "fact".utf8)
        // fact chunk length
        data.appendLittleEndian(UInt32(4))
        // sample length
        data.appendLittleEndian(dataLength / UInt32(bytesPerSample))
    }
}

private extension Data {
    mutating func appendLittleEndian<T: FixedWidthInteger>(_ value: T) {
        var value = value.littleEndian
        Swift.withUnsafeBytes(of: &value) { valueBytes in
            append(contentsOf: valueBytes)
        }
    }
}

public enum WaveFormat: UInt16 {
    case PCM = 1
    case IEEEFloat = 3
    case ALAW = 6
    case MULAW = 7
}
