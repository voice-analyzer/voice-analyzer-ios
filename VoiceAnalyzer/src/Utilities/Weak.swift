import Foundation

public struct Weak<T> {
    weak private var upcastValue: AnyObject?

    public var value: T? {
        get { return upcastValue as? T }
        set { upcastValue = newValue as AnyObject }
    }

    public init(_ value: T) {
        self.value = value
    }
}
