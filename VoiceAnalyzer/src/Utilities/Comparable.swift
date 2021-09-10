import Foundation

extension Comparable {
    func clamped(_ bounds: ClosedRange<Self>) -> Self {
        return min(max(self, bounds.lowerBound), bounds.upperBound)
    }

    func clamped(_ bound: PartialRangeFrom<Self>) -> Self {
        return max(self, bound.lowerBound)
    }

    func clamped(_ bound: PartialRangeThrough<Self>) -> Self {
        return min(self, bound.upperBound)
    }
}
