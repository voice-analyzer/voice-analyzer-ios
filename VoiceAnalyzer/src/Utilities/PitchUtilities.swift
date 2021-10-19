import Foundation

struct MusicalPitch {
    static let A0_HZ = 27.5

    static let MIN_VALUE = -2.0
    static let MAX_VALUE = 10.0

    /// Logarithmic-scale frequency, where A0 = 0.0, A1 = 1.0, ...
    let value: Double

    init?(value: Double) {
        guard (Self.MIN_VALUE...Self.MAX_VALUE).contains(value) else { return nil }
        self.value = value
    }

    init?(fromHz hz: Double) {
        self.init(value: log2(hz / Self.A0_HZ))
    }

    func closestNote() -> MusicalNote {
        let a0BasedIndex = Int(round(Double(MusicalNote.NAMES.count) * value))
        let c0BasedIndex = 9 + a0BasedIndex
        return MusicalNote(
            note: modulo(c0BasedIndex, modulus: UInt8(MusicalNote.NAMES.count)),
            octave: c0BasedIndex / 12
        )
    }

    func hz() -> Double {
        Self.A0_HZ * pow(2.0, value)
    }
}

struct MusicalNote {
    static let NAMES = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

    /// Index of semitone within an octave, starting from C
    let note: UInt8
    /// Octave number according to Scientific Pitch Notation
    let octave: Int

    init(note: UInt8, octave: Int) {
        self.note = note
        self.octave = octave
    }

    func description() -> String {
        "\(noteName())\(octave)"
    }

    func noteName() -> String {
        Self.NAMES[Int(note)]
    }

    func pitch() -> MusicalPitch {
        let c0BasedIndex = Int(note) + octave * 12
        let a0BasedIndex = c0BasedIndex - 9
        return MusicalPitch(value: Double(a0BasedIndex) / 12.0)!
    }
}

func modulo<X: SignedInteger, M: UnsignedInteger>(_ x: X, modulus: M) -> M {
    let remainder = x % X(modulus)
    return remainder < 0 ? M(remainder + X(modulus)) : M(remainder)
}
