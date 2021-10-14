import Foundation

struct MusicalPitch {
    static let A0_HZ = 27.5

    /// Logarithmic-scale frequency, where A0 = 0.0, A1 = 1.0, ...
    let value: Double

    init(value: Double) {
        self.value = value
    }

    init(fromHz hz: Double) {
        value = log2(hz / Self.A0_HZ)
    }

    func closestNote() -> MusicalNote {
        let a0BasedIndex = Int(round(Double(MusicalNote.NAMES.count) * value))
        let c0BasedIndex = 9 + a0BasedIndex
        return MusicalNote(
            note: UInt8(c0BasedIndex % MusicalNote.NAMES.count),
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
        return MusicalPitch(value: Double(a0BasedIndex) / 12.0)
    }
}
